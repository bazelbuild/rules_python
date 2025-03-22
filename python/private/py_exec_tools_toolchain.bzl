# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rule that defines a toolchain for build tools."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(":common.bzl", "runfiles_root_path")
load(":py_exec_tools_info.bzl", "PyExecToolsInfo")
load(":sentinel.bzl", "SentinelInfo")
load(":toolchain_types.bzl", "TARGET_TOOLCHAIN_TYPE")

def _py_exec_tools_toolchain_impl(ctx):
    extra_kwargs = {}
    if ctx.attr._visible_for_testing[BuildSettingInfo].value:
        extra_kwargs["toolchain_label"] = ctx.label

    exec_interpreter = ctx.attr.exec_interpreter
    if SentinelInfo in ctx.attr.exec_interpreter:
        exec_interpreter = None

    return [platform_common.ToolchainInfo(
        exec_tools = PyExecToolsInfo(
            exec_interpreter = exec_interpreter,
            precompiler = ctx.attr.precompiler,
        ),
        **extra_kwargs
    )]

py_exec_tools_toolchain = rule(
    implementation = _py_exec_tools_toolchain_impl,
    doc = """
Provides a toolchain for build time tools.

This provides `ToolchainInfo` with the following attributes:
* `exec_tools`: {type}`PyExecToolsInfo`
* `toolchain_label`: {type}`Label` _only present when `--visibile_for_testing=True`
  for internal testing_. The rule's label; this allows identifying what toolchain
  implmentation was selected for testing purposes.
""",
    attrs = {
        "exec_interpreter": attr.label(
            default = "//python/private:current_interpreter_executable",
            cfg = "exec",
            doc = """
An interpreter that is directly usable in the exec configuration

If not specified, the interpreter from {obj}`//python:toolchain_type` will
be used.

To disable, specify the special target {obj}`//python:none`; the raw value `None`
will use the default.

:::{note}
This is only useful for `ctx.actions.run` calls that _directly_ invoke the
interpreter, which is fairly uncommon and low level. It is better to use a
`cfg="exec"` attribute that points to a `py_binary` rule instead, which will
handle all the necessary transitions and runtime setup to invoke a program.
:::

See {obj}`PyExecToolsInfo.exec_interpreter` for further docs.
""",
        ),
        "precompiler": attr.label(
            allow_files = True,
            cfg = "exec",
            doc = "See {obj}`PyExecToolsInfo.precompiler`",
        ),
        "_visible_for_testing": attr.label(
            default = "//python/private:visible_for_testing",
        ),
    },
)

def relative_path(from_, to):
    """Compute a relative path from one path to another.

    Args:
        from_: {type}`str` the starting directory. Note that it should be
            a directory because relative-symlinks are relative to the
            directory the symlink resides in.
        to: {type}`str` the path that `from_` wants to point to

    Returns:
        {type}`str` a relative path
    """
    from_parts = from_.split("/")
    to_parts = to.split("/")

    # Strip common leading parts from both paths
    n = min(len(from_parts), len(to_parts))
    for _ in range(n):
        if from_parts[0] == to_parts[0]:
            from_parts.pop(0)
            to_parts.pop(0)
        else:
            break

    # Impossible to compute a relative path without knowing what ".." is
    if from_parts and from_parts[0] == "..":
        fail("cannot compute relative path from '%s' to '%s'", from_, to)

    parts = ([".."] * len(from_parts)) + to_parts
    return paths.join(*parts)

def _current_interpreter_executable_impl(ctx):
    toolchain = ctx.toolchains[TARGET_TOOLCHAIN_TYPE]
    runtime = toolchain.py3_runtime
    runfiles = []

    # NOTE: We name the output filename after the underlying file name
    # because of things like pyenv: they use $0 to determine what to
    # re-exec. If it's not a recognized name, then they fail.
    if runtime.interpreter:
        # Even though ctx.actions.symlink() could be used, we bump into the issue
        # with RBE where bazel is making a copy to the file instead of symlinking
        # to the hermetic toolchain repository. This means that we need to employ
        # a similar strategy to how the `py_executable` venv is created where the
        # file in the `runfiles` is a dangling symlink into the hermetic toolchain
        # repository. This smells like a bug in RBE, but I would not be surprised
        # if it is not one.

        # Create a dangling symlink in `bin/python3` to the real interpreter
        # in the hermetic toolchain.
        interpreter_basename = runtime.interpreter.basename
        executable = ctx.actions.declare_symlink("bin/" + interpreter_basename)
        runfiles.append(executable)
        interpreter_actual_path = runfiles_root_path(ctx, runtime.interpreter.short_path)
        target_path = relative_path(
            # dirname is necessary because a relative symlink is relative to
            # the directory the symlink resides within.
            from_ = paths.dirname(runfiles_root_path(ctx, executable.short_path)),
            to = interpreter_actual_path,
        )
        ctx.actions.symlink(output = executable, target_path = target_path)

        # Create a dangling symlink into the runfiles and use that as the
        # entry point.
        interpreter_actual_path = runfiles_root_path(ctx, executable.short_path)
        executable = ctx.actions.declare_symlink(interpreter_basename)
        target_path = interpreter_basename + ".runfiles/" + interpreter_actual_path
        ctx.actions.symlink(output = executable, target_path = target_path)
    else:
        executable = ctx.actions.declare_symlink(paths.basename(runtime.interpreter_path))
        runfiles.append(executable)
        ctx.actions.symlink(output = executable, target_path = runtime.interpreter_path)

    return [
        toolchain,
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(direct, transitive_files = runtime.files),
        ),
    ]

current_interpreter_executable = rule(
    implementation = _current_interpreter_executable_impl,
    toolchains = [TARGET_TOOLCHAIN_TYPE],
    executable = True,
)
