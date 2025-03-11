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
    args.add_all(["--custom-compile-command", "bazel run //{}:{}.update".format(
        ctx.label.package,
        ctx.label.name,
    )])
    args.add_all([
        "--no-python-downloads",
        "--no-cache",
    ])
    args.add_all(ctx.attr.args)

    # We use a manual param file so that we can forward it to the debug executable rule
    param_file = ctx.actions.declare_file(ctx.label.name + ".params")
    ctx.actions.write(
        output = param_file,
        content = args,
    )

    run_args = [param_file.path]
    args = ctx.actions.args()
    args.add_all(run_args)
    args.add_all(ctx.attr.run_args)

    cmd = ctx.executable._cmd

    srcs = ctx.files.srcs + ctx.files.maybe_out + [param_file]
    ctx.actions.run(
        executable = cmd,
        mnemonic = "RulesPythonUvPipCompile",
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
            cmd = ctx.attr._cmd,
            cmd_file = cmd,
            args = param_file,
            srcs = srcs,
        ),
    ]

_lock = rule(
    implementation = _lock_impl,
    doc = """\
""",
    attrs = {
        "args": attr.string_list(),
        "env": attr.string_dict(),
        "maybe_out": attr.label(allow_single_file = True),
        "out": attr.output(mandatory = True),
        "run_args": attr.string_list(),
        "srcs": attr.label_list(mandatory = True, allow_files = True),
        "_cmd": attr.label(
            default = "//python/uv/private:pip_compile",
            executable = True,
            cfg = "target",
        ),
    },
)

def _run_lock_impl(ctx):
    run_info = ctx.attr.lock[_LockRunInfo]
    params = ctx.actions.declare_file(ctx.label.name + ".params.txt")
    ctx.actions.symlink(
        output = params,
        target_file = run_info.args,
    )

    executable = ctx.actions.declare_file(ctx.label.name + ".exe")
    ctx.actions.symlink(
        output = executable,
        target_file = run_info.cmd_file,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = run_info.srcs + [run_info.cmd_file],
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

def lock(*, name, srcs, out, args = [], run_args = [], **kwargs):
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

    user_args = args
    args = [
        "--generate-hashes",
        "--emit-index-url",
        "--no-strip-extras",
    ]
    args += user_args
    maybe_out = _maybe_path(out)

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
        run_args = run_args,
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
    )

    _run_lock(
        name = locker_target,
        lock = name,
        args = run_args,
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
