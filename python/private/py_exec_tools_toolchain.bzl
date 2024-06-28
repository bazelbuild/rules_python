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

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//python/private:toolchain_types.bzl", "TARGET_TOOLCHAIN_TYPE")
load(":py_exec_tools_info.bzl", "PyExecToolsInfo")

def _py_exec_tools_toolchain_impl(ctx):
    extra_kwargs = {}
    if ctx.attr._visible_for_testing[BuildSettingInfo].value:
        extra_kwargs["toolchain_label"] = ctx.label

    return [platform_common.ToolchainInfo(
        exec_tools = PyExecToolsInfo(
            exec_interpreter = ctx.attr.exec_interpreter,
            precompiler = ctx.attr.precompiler,
        ),
        **extra_kwargs
    )]

py_exec_tools_toolchain = rule(
    implementation = _py_exec_tools_toolchain_impl,
    attrs = {
        "exec_interpreter": attr.label(
            default = "//python/private:current_interpreter_executable",
            cfg = "exec",
            doc = "See PyexecToolsInfo.exec_interpreter.",
        ),
        "precompiler": attr.label(
            allow_files = True,
            cfg = "exec",
            doc = "See PyExecToolsInfo.precompiler",
        ),
        "_visible_for_testing": attr.label(
            default = "//python/private:visible_for_testing",
        ),
    },
)

def _current_interpreter_executable_impl(ctx):
    toolchain = ctx.toolchains[TARGET_TOOLCHAIN_TYPE]
    runtime = toolchain.py3_runtime
    if runtime.interpreter:
        executable = ctx.actions.declare_file(ctx.label.name)
        ctx.actions.symlink(output = executable, target_file = runtime.interpreter, is_executable = True)
    else:
        executable = ctx.actions.declare_symlink(ctx.label.name)
        ctx.actions.symlink(output = executable, target_path = runtime.interpreter_path)
    return [
        toolchain,
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles([executable], transitive_files = runtime.files),
        ),
    ]

current_interpreter_executable = rule(
    implementation = _current_interpreter_executable_impl,
    toolchains = [TARGET_TOOLCHAIN_TYPE],
    executable = True,
)
