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

"""This module implements the uv toolchain rule"""

UvToolchainInfo = provider(
    doc = "Information about how to invoke the uv executable.",
    fields = {
        "binary": "uv binary",
        "version": "uv version",
    },
)

def _uv_toolchain_impl(ctx):
    binary = ctx.executable.uv

    templatevariableinfo = platform_common.TemplateVariableInfo({
        "UV_BIN": binary.path,
    })
    defaultinfo = DefaultInfo(
        files = depset([binary]),
        runfiles = ctx.runfiles(files = [binary]),
    )
    uvtoolchaininfo = UvToolchainInfo(
        binary = binary,
        version = ctx.attr.version.removeprefix("v"),
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
    toolchaininfo = platform_common.ToolchainInfo(
        uvtoolchaininfo = uvtoolchaininfo,
        templatevariableinfo = templatevariableinfo,
        defaultinfo = defaultinfo,
    )
    return [
        defaultinfo,
        toolchaininfo,
        templatevariableinfo,
    ]

uv_toolchain = rule(
    implementation = _uv_toolchain_impl,
    attrs = {
        "uv": attr.label(
            doc = "A static uv binary.",
            mandatory = False,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
        "version": attr.string(mandatory = True, doc = "Version of the uv binary."),
    },
    doc = "Defines a uv toolchain.",
)
