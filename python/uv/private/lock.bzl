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
load("//python:py_test.bzl", "py_test")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility

visibility(["//..."])

_uv_toolchain = Label("//python/uv:uv_toolchain_type")
_py_toolchain = Label("//python:toolchain_type")

_LockInfo = provider(
    doc = "",
    fields = {
        "args": "",
        "py": "",
        "srcs": "",
        "template": "",
        "uv": "",
    },
)

def _lock_impl(ctx):
    args = ctx.attr.args
    srcs = ctx.files.srcs
    existing_output = ctx.files.existing_output
    output = ctx.outputs.output

    toolchain_info = ctx.toolchains[_uv_toolchain]
    uv = toolchain_info.uv_toolchain_info.uv[DefaultInfo].files_to_run.executable

    py_runtime = ctx.toolchains[_py_toolchain].py3_runtime

    cmd = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.files._template[0],
        substitutions = {
            " uv ": " {} ".format(uv.path),
            "bazel_out": output.path,
            "replace": existing_output[0].path,
        },
        output = cmd,
        is_executable = True,
    )

    run_args = []
    lock_args = ctx.actions.args()
    lock_args.add("--no-python-downloads")
    run_args.append("--no-python-downloads")
    lock_args.add("--no-cache")
    run_args.append("--no-cache")
    if ctx.attr.generate_hashes:
        lock_args.add("--generate-hashes")
        run_args.append("--generate-hashes")
    if not ctx.attr.strip_extras:
        lock_args.add("--no-strip-extras")
        run_args.append("--no-strip-extras")

    update_command = "bazel run //{}:{}".format(
        ctx.label.package,
        ctx.attr.update_target,
    )
    lock_args.add("--custom-compile-command", update_command)
    run_args.extend(("--custom-compile-command", "'{}'".format(update_command)))

    lock_args.add("--no-progress")
    lock_args.add("--quiet")
    lock_args.add("--python", py_runtime.interpreter)
    lock_args.add_all(args)
    lock_args.add_all(srcs)

    ctx.actions.run(
        executable = cmd,
        mnemonic = "RulesPythonLock",
        inputs = srcs + ctx.files.existing_output,
        outputs = [output],
        arguments = [lock_args],
        tools = [cmd],
        progress_message = "Locking requirements using uv",
        env = ctx.attr.env,
    )

    return [
        DefaultInfo(files = depset([ctx.outputs.output])),
        _LockInfo(
            args = run_args + args,
            srcs = srcs,
            uv = uv,
            py = py_runtime,
            template = ctx.files._template[0],
        ),
    ]

_lock = rule(
    implementation = _lock_impl,
    doc = """\
""",
    attrs = {
        "args": attr.string_list(
            doc = "",
        ),
        "env": attr.string_dict(
            doc = "",
        ),
        "existing_output": attr.label(
            mandatory = False,
            allow_single_file = True,
            doc = """\
An already existing output file that is used as a basis for further
modifications and the locking is not done from scratch.
""",
        ),
        "generate_hashes": attr.bool(
            default = True,
            doc = """\
Generate hashes for all of the requirements. This is a must if you want to use
{attr}`pip.parse.experimental_index_url`.
""",
        ),
        "output": attr.output(
            mandatory = False,
            doc = """\
The output file to create that can then be synced to the source tree.
""",
        ),
        "python_version": attr.string(
            doc = """\
FIXME @aignas 2025-03-13: this needs to be a transition field. How do I do it?
""",
        ),
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
            doc = """\
The sources that will be used. Add all of the files that would be passed as
srcs to the `uv pip compile` command.
""",
        ),
        "strip_extras": attr.bool(
            default = False,
            doc = """\
Currently `rules_python` requires `--no-strip-extras` to properly function, but
sometimes one may want to not have the extras if you are compiling the
requirements file for using it as a constraints file.
""",
        ),
        "update_target": attr.string(
            mandatory = True,
            doc = """\
The string to input for the 'uv pip compile'.
""",
        ),
        "_template": attr.label(
            default = "//python/uv/private:pip_compile_template",
            cfg = "exec",
            executable = True,
            doc = """\
The template to be used for 'uv pip compile'. This is either .ps1 or bash
script depending on what the target platform is executed on.
""",
        ),
    },
    toolchains = [
        _uv_toolchain,
        _py_toolchain,
    ],
)

def _lock_run_impl(ctx):
    info = ctx.attr.lock[_LockInfo]
    uv = info.uv
    srcs = info.srcs
    py_runtime = info.py

    args = [
        uv.short_path,
        "pip",
        "compile",
    ] + info.args + [
        src.short_path
        for src in srcs
    ] + [
        "--python",
        py_runtime.interpreter.short_path,
    ]

    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.expand_template(
        template = info.template,
        substitutions = {
            "replace": "{}/{}".format(ctx.label.package, ctx.attr.output),
            "uv pip compile": " ".join(args),
        },
        output = executable,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        transitive_files = depset(
            srcs + [uv],
            transitive = [
                py_runtime.files,
            ],
        ),
    )
    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
    ]

_lock_run = rule(
    implementation = _lock_run_impl,
    doc = """\
""",
    attrs = {
        "lock": attr.label(
            doc = "The lock target that is doing locking in a build action.",
            providers = [_LockInfo],
        ),
        "output": attr.string(
            doc = "The output that we would be updated.",
        ),
    },
    executable = True,
)

def _maybe_file(path):
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

def lock(*, name, srcs, out, args = [], env = None, **kwargs):
    """Pin the requirements based on the src files.

    Differences with the current {obj}`compile_pip_requirements` rule:
    - This is implemented as a rule that performs locking in a build action.
    - Additionally one can use the runnable target.
    - Uses `uv`.
    - This does not error out if the output file does not exist yet.
    - Supports transitions out of the box.
    - The execution of the lock file generation is happening inside of a build
      action in a `genrule`.

    Args:
        name: The name of the target to run for updating the requirements.
        srcs: The srcs to use as inputs.
        out: The output file.
        args: Extra args to pass to `uv`.
        env: Passed to `uv`.
        **kwargs: Extra kwargs passed to the {obj}`py_test` rule.
    """
    update_target = "{}.update".format(name)
    locker_target = "{}.run".format(name)
    maybe_out = _maybe_file(out)
    out_new = out + ".new"
    target_compatible_with = kwargs.pop("target_compatible_with", select({
        "@platforms//os:windows": ["@platforms//:incompatible"],
        "//conditions:default": [],
    })) if BZLMOD_ENABLED else ["@platforms//:incompatible"]

    _lock(
        name = name,
        srcs = srcs,
        # Check if the output file already exists, if yes, first copy it to the
        # output file location in order to make `uv` not change the requirements if
        # we are just running the command.
        existing_output = maybe_out,
        update_target = update_target,
        output = out_new,
        tags = [
            "local",
            "manual",
            "no-cache",
            "requires-network",
        ],
        args = args,
        env = env,
        target_compatible_with = target_compatible_with,
    )

    # A target for updating the in-tree version directly by skipping the in-action
    # uv pip compile.
    _lock_run(
        name = locker_target,
        lock = name,
        # TODO @aignas 2025-03-13: should we actually update the in-tree
        # version with this? For now I think that yes because we may want to
        # specify extra args like `--upgrade` or `-P mypkg` to upgrade some of
        # the packages.
        output = out,
        # TODO @aignas 2025-03-13: allow customizing the env
        # env = env,
        tags = ["manual"],
    )

    # Write a script that can be used for updating the in-tree version of the
    # requirements file
    pkg = native.package_name()
    expand_template(
        name = update_target + "_gen",
        out = update_target + ".py",
        template = "//python/uv/private:copy.py",
        substitutions = {
            'dst = ""': 'dst = "{}/{}"'.format(pkg, out),
            'src = ""': 'src = "{}/{}"'.format(pkg, out_new),
        },
    )

    # TODO @aignas 2025-03-13: create a py_test-like target if the design of
    # having a single test and runnable target that do 2 separate things is
    # good enough, in theory we can have a single rule that does the template
    # substitution and run the test.
    #
    # This is just for running the diff test. If the file is out of date, we
    # would have the out_new in the bazel cache already and the synching with
    # the source version would be instantaneous.
    py_test(
        name = update_target,
        srcs = [update_target + ".py"],
        data = [out_new] + ([] if not maybe_out else [maybe_out]),
        **kwargs
    )
