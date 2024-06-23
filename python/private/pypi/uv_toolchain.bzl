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
        "uv_files": """Files required in runfiles to make the uv executable available.

May be empty if the uv_path points to a locally installed uv binary.""",
        "uv_path": "Path to the uv executable.",
    },
)

# Avoid using non-normalized paths (workspace/../other_workspace/path)
def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return "external/" + file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _uv_toolchain_impl(ctx):
    if ctx.attr.uv_tool and ctx.attr.uv_path:
        fail("Can only set one of uv_tool or uv_path but both were set.")
    if not ctx.attr.uv_tool and not ctx.attr.uv_path:
        fail("Must set one of uv_tool or uv_path.")

    uv_files = []
    uv_path = ctx.attr.uv_path

    if ctx.attr.uv_tool:
        uv_files = ctx.attr.uv_tool.files.to_list()
        uv_path = _to_manifest_path(ctx, tool_files[0])

    # Make the $(UV_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    templatevariableinfo = platform_common.TemplateVariableInfo({
        "UV_BIN": uv_path,
    })
    defaultinfo = DefaultInfo(
        files = depset(uv_files),
        runfiles = ctx.runfiles(files = uv_files),
    )
    uvtoolchaininfo = UvToolchainInfo(
        uv_path = uv_path,
        uv_files = uv_files,
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
        "uv_path": attr.string(
            doc = "Path to an existing uv executable",
            mandatory = False,
        ),
        "uv_tool": attr.label(
            doc = "A hermetically downloaded executable target for the target platform.",
            mandatory = False,
            allow_single_file = True,
        ),
    },
    doc = "Defines a uv toolchain.",
)
