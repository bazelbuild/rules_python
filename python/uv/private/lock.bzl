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

load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("//python:py_binary.bzl", "py_binary")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility

visibility(["//..."])

_REQUIREMENTS_TARGET_COMPATIBLE_WITH = [] if BZLMOD_ENABLED else ["@platforms//:incompatible"]

_LockRunInfo = provider(
    doc = "Information about source tree for Sphinx to build.",
    fields = {
        "args": "",
        "cmd": "",
        "cmd_file": "",
        "srcs": "",
    },
)

def _lock_impl(ctx):
    args = ctx.actions.args()
    if ctx.files.maybe_out:
        args.add_all([
            "--src-out",
            ctx.files.maybe_out[0].path,
        ])
    args.add("--output-file", ctx.outputs.out)
    args.add_all(ctx.files.srcs)

    # We use a manual param file so that we can forward it to the debug executable rule
    param_file = ctx.actions.declare_file(ctx.label.name + ".params.txt")
    ctx.actions.write(
        output = param_file,
        content = args,
    )

    run_args = [param_file.path]
    args = ctx.actions.args()
    args.add_all(run_args)

    cmd = ctx.executable.cmd

    srcs = ctx.files.srcs + ctx.files.maybe_out + [param_file]
    ctx.actions.run(
        executable = ctx.executable.cmd,
        mnemonic = "RulesPythonLock",
        inputs = srcs,
        outputs = [ctx.outputs.out],
        arguments = [args],
        tools = [cmd],
        progress_message = "Locking requirements using uv",
        env = ctx.attr.env,
    )

    return [
        DefaultInfo(
            files = depset([ctx.outputs.out]),
        ),
        _LockRunInfo(
            cmd = ctx.attr.cmd,
            cmd_file = ctx.executable.cmd,
            args = run_args,
            srcs = srcs,
        ),
    ]

_lock = rule(
    implementation = _lock_impl,
    doc = """\
""",
    attrs = {
        "args": attr.string_list(),
        "cmd": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
        ),
        "env": attr.string_dict(),
        "maybe_out": attr.label(allow_single_file = True),
        "out": attr.output(mandatory = True),
        "srcs": attr.label_list(mandatory = True, allow_files = True),
    },
)

def _run_lock_impl(ctx):
    run_info = ctx.attr.lock[_LockRunInfo]
    executable = ctx.actions.declare_file(ctx.label.name + ".exe")
    ctx.actions.symlink(
        output = executable,
        target_file = run_info.cmd_file,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = run_info.srcs,
        transitive_files = run_info.cmd[DefaultInfo].files,
    ).merge(run_info.cmd[DefaultInfo].default_runfiles)

    return DefaultInfo(
        executable = executable,
        runfiles = runfiles,
    )

_run_lock = rule(
    implementation = _run_lock_impl,
    doc = """\
""",
    attrs = {
        "lock": attr.label(
            mandatory = True,
            providers = [_LockRunInfo],
        ),
        "_template": attr.label(
            default = "//python/uv/private:pip_compile.py",
            allow_single_file = True,
        ),
    },
    executable = True,
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
    update_target = "{}.update".format(name)
    locker_target = "{}.run".format(name)

    # TODO @aignas 2025-03-02: move the following args to a template expansion action
    user_args = args
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

    run_args = []
    maybe_out = _maybe_path(out)
    if maybe_out:
        # This means that the output file already exists and it should be used
        # to create a new file. This will be taken care by the locker tool.
        #
        # TODO @aignas 2025-03-02: similarly to sphinx rule, expand the output to short_path
        run_args += ["--output-file", "$(rootpath {})".format(maybe_out)]
    else:
        # TODO @aignas 2025-03-02: pass the output as a string
        run_out = "{}/{}".format(pkg, out)
        run_args += ["--output-file", run_out]

    # args just get passed as is
    run_args += [
        # TODO @aignas 2025-03-02: get the full source location for these
        "$(rootpath {})".format(s)
        for s in srcs
    ]

    expand_template(
        name = locker_target + "_gen",
        out = locker_target + ".py",
        template = "//python/uv/private:pip_compile.py",
        substitutions = {
            "    args = []": "    args = " + repr(args),
        },
        tags = ["manual"],
    )

    py_binary(
        name = locker_target,
        srcs = [locker_target + ".py"],
        data = [
            "//python/uv:current_toolchain",
        ] + srcs + ([maybe_out] if maybe_out else []),
        args = run_args,
        python_version = kwargs.get("python_version"),
        tags = ["manual"],
        deps = ["//python/runfiles"],
    )

    _lock(
        name = name,
        srcs = srcs,
        # Check if the output file already exists, if yes, first copy it to the
        # output file location in order to make `uv` not change the requirements if
        # we are just running the command.
        maybe_out = maybe_out,
        out = out + ".new",
        tags = [
            "local",
            "manual",
            "no-cache",
        ],
        args = args,
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
        cmd = locker_target,
    )

    _run_lock(
        name = name + ".run2",
        lock = name,
    )

    if maybe_out:
        diff_test(
            name = name + "_test",
            file1 = out + ".new",
            file2 = maybe_out,
            tags = ["manual"],
        )

    # Write a script that can be used for updating the in-tree version of the
    # requirements file
    expand_template(
        name = update_target + "_gen",
        out = update_target + ".py",
        template = "//python/uv/private:copy.py",
        substitutions = {
            'dst = ""': 'dst = "{}/{}"'.format(pkg, out),
        },
    )

    py_binary(
        name = update_target,
        srcs = [update_target + ".py"],
        data = [name],
        env = {
            "REQUIREMENTS_FILE": "$(rootpath {})".format(name),
        },
        tags = ["manual"],
        **kwargs
    )

def _maybe_path(path):
    """A small function to return a list of existing outputs.

    If the file referenced by the input argument exists, then it will return
    it, otherwise it will return an empty list. This is useful to for programs
    like pip-compile which behave differently if the output file exists and
    update the output file in place.

    The API of the function ensures that path is not a glob itself.

    Args:
        path: {type}`str` the file name.
    """
    for p in native.glob([path], allow_empty = True):
        if path == p:
            return p

    return None
