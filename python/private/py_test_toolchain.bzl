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

"""
Simple toolchain which overrides env and exec requirements.
"""

PytestProvider = provider(
    fields = [
        "coverage_rc",
    ],
)

def _py_test_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            py_test_info = PytestProvider(
                coverage_rc = ctx.attr.coverage_rc,
            ),
        ),
    ]

py_test_toolchain = rule(
    implementation = _py_test_toolchain_impl,
    attrs = {
        "coverage_rc": attr.label(
            allow_single_file = True,
        ),
    },
)
_TOOLCHAIN_TEMPLATE = """
load("@rules_python//python/private:py_test_toolchain.bzl", "py_test_toolchain")
py_test_toolchain(
    name = "{name}_toolchain",
    coverage_rc = "{coverage_rc}",
)

toolchain(
    name = "{name}",
    target_compatible_with = [],
    exec_compatible_with = [],
    toolchain = "{name}_toolchain",
    toolchain_type = "{toolchain_type}",
)
"""

def _toolchains_repo_impl(repository_ctx):
    build_content = _TOOLCHAIN_TEMPLATE.format(
        name = repository_ctx.name,
        toolchain_type = repository_ctx.attr.toolchain_type,
        coverage_rc = repository_ctx.attr.coverage_rc,
    )
    repository_ctx.file("BUILD.bazel", build_content)

py_test_toolchain_repo = repository_rule(
    _toolchains_repo_impl,
    doc = "Generates a toolchain hub repository",
    attrs = {
        "toolchain_type": attr.string(doc = "Toolchain type", mandatory = True),
        "coverage_rc": attr.label(
            allow_single_file = True,
            doc = "The coverage rc file",
            mandatory = True,
        ),
    },
)
