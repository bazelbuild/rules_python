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

load(":text_util.bzl", "render")
load(
    ":toolchain_types.bzl",
    "PY_TEST_TOOLCHAIN_TYPE",
)

PyTestProviderInfo = provider(
    doc = "Information about the pytest toolchain",
    fields = [
        "coverage_rc",
    ],
)

def _py_test_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            py_test_info = PyTestProviderInfo(
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
load("@rules_python//python/private:py_test_toolchain.bzl", "py_test_toolchain_macro")
py_test_toolchain_macro(
     {kwargs}
)
"""

def py_test_toolchain_macro(*, name, coverage_rc, toolchain_type):
    """
    Macro to create a py_test_toolchain rule and a native toolchain rule.

    name: The name of the toolchain.
    coverage_rc: The coverage rc file.
    toolchain_type: The toolchain type.
    """
    py_test_toolchain(
        name = "{}_toolchain".format(name),
        coverage_rc = coverage_rc,
    )
    native.toolchain(
        name = name,
        target_compatible_with = [],
        exec_compatible_with = [],
        toolchain = "{}_toolchain".format(name),
        toolchain_type = toolchain_type,
    )

def _toolchains_repo_impl(repository_ctx):
    kwargs = dict(
        name = repository_ctx.name,
        coverage_rc = str(repository_ctx.attr.coverage_rc),
        toolchain_type = str(repository_ctx.attr.toolchain_type),
    )

    build_content = _TOOLCHAIN_TEMPLATE.format(
        kwargs = render.indent("\n".join([
            "{} = {},".format(k, render.str(v))
            for k, v in kwargs.items()
        ])),
    )
    repository_ctx.file("BUILD.bazel", build_content)

py_test_toolchain_repo = repository_rule(
    _toolchains_repo_impl,
    doc = "Generates a toolchain hub repository",
    attrs = {
        "coverage_rc": attr.label(
            allow_single_file = True,
            doc = "The coverage rc file",
            mandatory = True,
        ),
        "toolchain_type": attr.label(doc = "Toolchain type", mandatory = True),
    },
)

def register_py_test_toolchain(name, coverage_rc, register_toolchains = True):
    """ Register the py_test_toolchain and native toolchain rules.

    name: The name of the toolchain.
    coverage_rc: The coverage rc file.
    register_toolchains: Whether to register the toolchains.

    """
    py_test_toolchain_repo(
        name = name,
        coverage_rc = coverage_rc,
        toolchain_type = PY_TEST_TOOLCHAIN_TYPE,
    )
    if register_toolchains:
        native.toolchain(name = "py_test_toolchain")
