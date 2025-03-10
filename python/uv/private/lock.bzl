# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""A simple macro to lock the requirements.
"""

load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//python:py_binary.bzl", "py_binary")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility

visibility(["//..."])

_REQUIREMENTS_TARGET_COMPATIBLE_WITH = [] if BZLMOD_ENABLED else ["@platforms//:incompatible"]

_RunLockInfo = provider(
    doc = "Information for running the underlying Sphinx command directly",
    fields = {
        "cmd": """
:type: Target

The locker binary to run.
""",
    },
)

def _impl(ctx):
    args = ctx.actions.args()

    # TODO @aignas 2025-03-02: create an executable file here that is using a
    # python and uv toolchains.
    if ctx.files.src_outs:
        args.add_all([
            "--src-out",
            ctx.files.src_outs[0].path,
        ])
    args.add("--output-file", ctx.outputs.out)

    # TODO @aignas 2025-03-02: add the following deps to _RunLockInfo
    srcs = ctx.files.srcs + ctx.files.src_outs
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable.cmd,
        mnemonic = "RulesPythonLock",
        inputs = srcs,
        outputs = [
            ctx.outputs.out,
        ],
        arguments = [args],
        tools = [
            ctx.executable.cmd,
        ],
        progress_message = "Locking requirements using uv",
        env = ctx.attr.env,
    )

    return [
        DefaultInfo(files = depset([ctx.outputs.out])),
        _RunLockInfo(cmd = ctx.executable.cmd),
    ]

_lock = rule(
    implementation = _impl,
    doc = """\
""",
    attrs = {
        "args": attr.string_list(),
        "cmd": attr.label(
            default = "//python/uv/private:pip_compile",
            executable = True,
            cfg = "target",
        ),
        "env": attr.string_dict(),
        "out": attr.output(mandatory = True),
        "src_outs": attr.label_list(mandatory = True, allow_files = True),
        "srcs": attr.label_list(mandatory = True, allow_files = True),
    },
)

def lock(*, name, srcs, out, args = [], **kwargs):
    """Pin the requirements based on the src files.

    Differences with the current {obj}`compile_pip_requirements` rule:
    - This is implemented as a rule that performs locking in a build action.
    - Additionally one can use the runnable target.
    - Uses `uv`.
    - This does not error out if the output file does not exist yet.
    - Supports transitions out of the box.

    Args:
        name: The name of the target to run for updating the requirements.
        srcs: The srcs to use as inputs.
        out: The output file.
        args: Extra args to pass to `uv`.
        **kwargs: Extra kwargs passed to the {obj}`py_binary` rule.
    """
    pkg = native.package_name()
    update_target = name + ".update"

    user_args = args

    existing_outputs = []
    for path in native.glob([out], allow_empty = True):
        if path == out:
            existing_outputs = [out]
            break

    # TODO @aignas 2025-03-02: move the following args to a template expansion action
    args = [
        # FIXME @aignas 2025-03-02: this acts differently in native_binary and the rule
        "--custom-compile-command='bazel run //{}:{}'".format(pkg, update_target),
        "--generate-hashes",
        "--emit-index-url",
        "--no-strip-extras",
        "--no-python-downloads",
        "--no-cache",
    ]
    args += user_args

    expand_template(
        name = name + "_locker_src",
        out = name + "_locker.py",
        template = "//python/uv/private:pip_compile.py",
        substitutions = {
            "    args = []": "    args = " + repr(args),
        },
        tags = ["manual"],
    )

    py_binary(
        name = name + "_locker",
        srcs = [name + "_locker.py"],
        data = [
            "//python/uv:current_toolchain",
        ],
        tags = ["manual"],
        deps = ["//python/runfiles"],
    )

    _lock(
        name = name,
        srcs = srcs,
        # Check if the output file already exists, if yes, first copy it to the
        # output file location in order to make `uv` not change the requirements if
        # we are just running the command.
        src_outs = existing_outputs,
        out = out + ".new",
        tags = [
            "local",
            "manual",
            "no-cache",
        ],
        args = args,
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
        cmd = name + "_locker",
    )

    run_args = []
    if existing_outputs:
        # This means that the output file already exists and it should be used
        # to create a new file. This will be taken care by the locker tool.
        #
        # TODO @aignas 2025-03-02: similarly to sphinx rule, expand the output to short_path
        run_args += ["--output-file", "$(location {})".format(existing_outputs[0])]
    else:
        # TODO @aignas 2025-03-02: pass the output as a string
        run_out = "{}/{}".format(pkg, out)
        run_args += ["--output-file", run_out]

    # args just get passed as is
    run_args += args + [
        # TODO @aignas 2025-03-02: get the full source location for these
        "$(location {})".format(s)
        for s in srcs
    ]

    native_binary(
        # this is expand_template using the stuff from the provider from the _lock rule
        name = name + ".run",
        args = run_args,  # the main difference is the expansion of args here
        data = srcs + existing_outputs,  # This only depends on inputs to the _lock
        src = "//python/uv/private:pip_compile",
        tags = [
            "local",
            "manual",
            "no-cache",
        ],
    )

    # Write a script that can be used for updating the in-tree version of the
    # requirements file
    write_file(
        name = name + ".update_gen",
        out = update_target + ".py",
        content = [
            "from os import environ",
            "from pathlib import Path",
            "from sys import stderr",
            "",
            'src = Path(environ["REQUIREMENTS_FILE"])',
            'assert src.exists(), f"the {src} file does not exist"',
            'dst = "{}/{}"'.format(pkg, out),
            'print(f"cp <bazel-sandbox>/{src}\\n    -> <workspace>/{dst}", file=stderr)',
            'build_workspace = Path(environ["BUILD_WORKSPACE_DIRECTORY"])',
            "dst = build_workspace / dst",
            "dst.write_text(src.read_text())",
            'print("Success!", file=stderr)',
        ],
    )

    py_binary(
        name = update_target,
        srcs = [update_target + ".py"],
        main = update_target + ".py",
        data = [name],
        env = {
            "REQUIREMENTS_FILE": "$(rootpath {})".format(name),
        },
        tags = ["manual"],
        **kwargs
    )
