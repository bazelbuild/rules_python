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

"render_pkg_aliases tests"

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private:render_pkg_aliases.bzl", "render_pkg_aliases")  # buildifier: disable=bzl-visibility

_tests = []

def _test_legacy_aliases(env):
    actual = render_pkg_aliases(
        bzl_packages = ["foo"],
        repo_name = "pypi",
    )

    want = {
        "foo/BUILD.bazel": """\
package(default_visibility = ["//visibility:public"])

alias(
    name = "foo",
    actual = "@pypi_foo//:pkg",
)

alias(
    name = "pkg",
    actual = "@pypi_foo//:pkg",
)

alias(
    name = "whl",
    actual = "@pypi_foo//:whl",
)

alias(
    name = "data",
    actual = "@pypi_foo//:data",
)

alias(
    name = "dist_info",
    actual = "@pypi_foo//:dist_info",
)""",
    }

    env.expect.that_dict(actual).contains_exactly(want)

_tests.append(_test_legacy_aliases)

def _test_all_legacy_aliases_are_created(env):
    actual = render_pkg_aliases(
        bzl_packages = ["foo", "bar"],
        repo_name = "pypi",
    )

    want_files = ["bar/BUILD.bazel", "foo/BUILD.bazel"]

    env.expect.that_dict(actual).keys().contains_exactly(want_files)

_tests.append(_test_all_legacy_aliases_are_created)

def _test_bzlmod_aliases(env):
    actual = render_pkg_aliases(
        default_version = "3.2.3",
        repo_name = "pypi",
        rules_python = "rules_python",
        whl_map = {
            "bar-baz": ["3.2.3"],
        },
    )

    want = {
        "bar_baz/BUILD.bazel": """\
package(default_visibility = ["//visibility:public"])

alias(
    name = "bar_baz",
    actual = select({
        "@@rules_python//python/config_settings:is_python_3.2.3": "@pypi_32_bar_baz//:pkg",
        "//conditions:default": "@pypi_32_bar_baz//:pkg",
    }),
)

alias(
    name = "pkg",
    actual = select({
        "@@rules_python//python/config_settings:is_python_3.2.3": "@pypi_32_bar_baz//:pkg",
        "//conditions:default": "@pypi_32_bar_baz//:pkg",
    }),
)

alias(
    name = "whl",
    actual = select({
        "@@rules_python//python/config_settings:is_python_3.2.3": "@pypi_32_bar_baz//:whl",
        "//conditions:default": "@pypi_32_bar_baz//:whl",
    }),
)

alias(
    name = "data",
    actual = select({
        "@@rules_python//python/config_settings:is_python_3.2.3": "@pypi_32_bar_baz//:data",
        "//conditions:default": "@pypi_32_bar_baz//:data",
    }),
)

alias(
    name = "dist_info",
    actual = select({
        "@@rules_python//python/config_settings:is_python_3.2.3": "@pypi_32_bar_baz//:dist_info",
        "//conditions:default": "@pypi_32_bar_baz//:dist_info",
    }),
)""",
        "bar_baz/bin_py32/BUILD.bazel": """\
load("@pypi_32_bar_baz//:entry_points.bzl", "entry_points")

[
    alias(
        name = script,
        actual = "@pypi_32_bar_baz//:" + target,
        visibility = ["//visibility:public"],
    )
    for script, target in entry_points.items()
]""",
    }

    env.expect.that_dict(actual).contains_exactly(want)

_tests.append(_test_bzlmod_aliases)

def _test_bzlmod_aliases_are_created_for_all_wheels(env):
    actual = render_pkg_aliases(
        default_version = "3.2.3",
        repo_name = "pypi",
        rules_python = "rules_python",
        whl_map = {
            "bar": ["3.1.2", "3.2.3"],
            "foo": ["3.1.2", "3.2.3"],
        },
    )

    want_files = [
        "bar/BUILD.bazel",
        "bar/bin_py31/BUILD.bazel",
        "bar/bin_py32/BUILD.bazel",
        "foo/BUILD.bazel",
        "foo/bin_py31/BUILD.bazel",
        "foo/bin_py32/BUILD.bazel",
    ]

    env.expect.that_dict(actual).keys().contains_exactly(want_files)

_tests.append(_test_bzlmod_aliases_are_created_for_all_wheels)

def render_pkg_aliases_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
