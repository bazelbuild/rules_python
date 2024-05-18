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

load("//python/private/common:providers.bzl", "interpreter_version_info_struct_from_dict")
load(":py_exec_tools_info.bzl", "PyExecToolsInfo")

def _py_exec_tools_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(exec_tools = PyExecToolsInfo(
        exec_interpreter = ctx.attr.exec_interpreter,
        exec_interpreter_version_info = interpreter_version_info_struct_from_dict(
            ctx.attr.exec_interpreter_version_info,
        ),
        precompiler = ctx.attr.precompiler,
    ))]

py_exec_tools_toolchain = rule(
    implementation = _py_exec_tools_toolchain_impl,
    attrs = {
        "exec_interpreter": attr.label(
            cfg = "exec",
            allow_files = True,
            doc = "See PyExecToolsInfo.exec_interpreter",
            executable = True,
        ),
        "exec_interpreter_version_info": attr.string_dict(
            doc = "See PyExecToolsInfo.exec_interpreter_version_info",
        ),
        "precompiler": attr.label(
            allow_files = True,
            cfg = "exec",
            doc = "See PyExecToolsInfo.precompiler",
        ),
    },
)
