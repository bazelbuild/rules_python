# Copyright 2023 The Bazel Authors. All rights reserved.
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

"Python toolchain module extensions for use with bzlmod"

load("@rules_python//python:repositories.bzl", "python_register_toolchains")
load("@rules_python//python/extensions/private:interpreter_hub.bzl", "hub_repo")

def _python_impl(module_ctx):
    toolchains = []
    for mod in module_ctx.modules:
        for toolchain_attr in mod.tags.toolchain:
            python_register_toolchains(
                name = toolchain_attr.name,
                python_version = toolchain_attr.python_version,
                bzlmod = True,
                # Toolchain registration in bzlmod is done in MODULE file
                register_toolchains = False,
                register_coverage_tool = toolchain_attr.configure_coverage_tool,
                ignore_root_user_error = toolchain_attr.ignore_root_user_error,
            )

            # We collect all of the toolchain names to create
            # the INTERPRETER_LABELS map.  This is used
            # by interpreter_extensions.bzl
            toolchains.append(toolchain_attr.name)

    hub_repo(
        name = "pythons_hub",
        toolchains = toolchains,
    )

python = module_extension(
    doc = "Bzlmod extension that is used to register a Python toolchain.",
    implementation = _python_impl,
    tag_classes = {
        "toolchain": tag_class(
            attrs = {
                "configure_coverage_tool": attr.bool(
                    mandatory = False,
                    doc = "Whether or not to configure the default coverage tool for the toolchains.",
                ),
                "ignore_root_user_error": attr.bool(
                    default = False,
                    doc = "Whether the check for root should be ignored or not. This causes cache misses with .pyc files.",
                    mandatory = False,
                ),
                "name": attr.string(mandatory = True),
                "python_version": attr.string(mandatory = True),
            },
        ),
    },
)
