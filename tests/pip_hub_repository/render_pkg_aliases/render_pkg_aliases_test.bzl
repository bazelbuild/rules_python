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

"""render_pkg_aliases tests"""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private:render_pkg_aliases.bzl", "render_pkg_aliases", "whl_alias")  # buildifier: disable=bzl-visibility

def _normalize_labels(want):
    # Do not modify the `want` on bazel 7+
    if hasattr(native, "starlark_doc_extract"):
        return want

    return {
        key: value.replace("\"@/", "\"@@/")
        for key, value in want.items()
    }

_tests = []

def _test_empty(env):
    actual = render_pkg_aliases(
        aliases = None,
    )

    want = {}

    env.expect.that_dict(actual).contains_exactly(want)

_tests.append(_test_empty)

def _test_legacy_aliases(env):
    actual = render_pkg_aliases(
        aliases = [
            whl_alias(name = "foo", repo_prefix = "pypi_"),
        ],
    )

    want = {
        "foo/BUILD.bazel": """\
package(default_visibility = ["//visibility:public"])

alias(
    name = "foo",
    actual = ":pkg",
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

    env.expect.that_dict(actual).contains_exactly(_normalize_labels(want))

_tests.append(_test_legacy_aliases)

def _test_all_legacy_aliases_are_created(env):
    actual = render_pkg_aliases(
        aliases = [
            whl_alias(name = "bar", repo_prefix = "pypi_"),
            whl_alias(name = "foo", repo_prefix = "pypi_"),
        ],
    )

    want_files = ["bar/BUILD.bazel", "foo/BUILD.bazel"]

    env.expect.that_dict(actual).keys().contains_exactly(want_files)

_tests.append(_test_all_legacy_aliases_are_created)

def _test_bzlmod_aliases(env):
    actual = render_pkg_aliases(
        default_version = "3.2",
        aliases = [
            whl_alias(name = "bar-baz", version = "3.2", repo_prefix = "pypi_32_"),
        ],
    )

    want = {
        "bar_baz/BUILD.bazel": """\
package(default_visibility = ["//visibility:public"])

alias(
    name = "bar_baz",
    actual = ":pkg",
)

alias(
    name = "pkg",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:pkg",
            "//conditions:default": "@pypi_32_bar_baz//:pkg",
        },
    ),
)

alias(
    name = "whl",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:whl",
            "//conditions:default": "@pypi_32_bar_baz//:whl",
        },
    ),
)

alias(
    name = "data",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:data",
            "//conditions:default": "@pypi_32_bar_baz//:data",
        },
    ),
)

alias(
    name = "dist_info",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:dist_info",
            "//conditions:default": "@pypi_32_bar_baz//:dist_info",
        },
    ),
)""",
    }

    env.expect.that_dict(actual).contains_exactly(_normalize_labels(want))

_tests.append(_test_bzlmod_aliases)

def _test_bzlmod_aliases_with_no_default_version(env):
    actual = render_pkg_aliases(
        default_version = None,
        aliases = [
            whl_alias(name = "bar-baz", version = "3.2", repo_prefix = "pypi_32_"),
            whl_alias(name = "bar-baz", version = "3.1", repo_prefix = "pypi_31_"),
        ],
    )

    want_key = "bar_baz/BUILD.bazel"
    want_content = """\
package(default_visibility = ["//visibility:public"])

_NO_MATCH_ERROR = \"\"\"\\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
versions available for this wheel. This wheel supports the following Python versions:
    3.1, 3.2

As matched by the `@rules_python//python/config_settings:is_python_<version>`
configuration settings.

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    rules_python//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
\"\"\"

alias(
    name = "bar_baz",
    actual = ":pkg",
)

alias(
    name = "pkg",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:pkg",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:pkg",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "whl",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:whl",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:whl",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "data",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:data",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:data",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "dist_info",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:dist_info",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:dist_info",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)"""

    env.expect.that_collection(actual.keys()).contains_exactly([want_key])
    env.expect.that_str(actual[want_key]).equals(want_content)

_tests.append(_test_bzlmod_aliases_with_no_default_version)

def _test_bzlmod_aliases_for_non_root_modules(env):
    actual = render_pkg_aliases(
        # NOTE @aignas 2024-01-17: if the default X.Y version coincides with the
        # versions that are used in the root module, then this would be the same as
        # as _test_bzlmod_aliases.
        #
        # However, if the root module uses a different default version than the
        # non-root module, then we will have a no-match-error because the default_version
        # is not in the list of the versions in the whl_map.
        default_version = "3.3",
        aliases = [
            whl_alias(name = "bar-baz", version = "3.2", repo_prefix = "pypi_32_"),
            whl_alias(name = "bar-baz", version = "3.1", repo_prefix = "pypi_31_"),
        ],
    )

    want_key = "bar_baz/BUILD.bazel"
    want_content = """\
package(default_visibility = ["//visibility:public"])

_NO_MATCH_ERROR = \"\"\"\\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
versions available for this wheel. This wheel supports the following Python versions:
    3.1, 3.2

As matched by the `@rules_python//python/config_settings:is_python_<version>`
configuration settings.

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    rules_python//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
\"\"\"

alias(
    name = "bar_baz",
    actual = ":pkg",
)

alias(
    name = "pkg",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:pkg",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:pkg",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "whl",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:whl",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:whl",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "data",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:data",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:data",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "dist_info",
    actual = select(
        {
            "@@//python/config_settings:is_python_3.1": "@pypi_31_bar_baz//:dist_info",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:dist_info",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)"""

    env.expect.that_collection(actual.keys()).contains_exactly([want_key])
    env.expect.that_str(actual[want_key]).equals(want_content)

_tests.append(_test_bzlmod_aliases_for_non_root_modules)

def _test_bzlmod_aliases_are_created_for_all_wheels(env):
    actual = render_pkg_aliases(
        default_version = "3.2",
        aliases = [
            whl_alias(name = "bar", version = "3.1", repo_prefix = "pypi_31_"),
            whl_alias(name = "bar", version = "3.2", repo_prefix = "pypi_32_"),
            whl_alias(name = "foo", version = "3.1", repo_prefix = "pypi_32_"),
            whl_alias(name = "foo", version = "3.2", repo_prefix = "pypi_31_"),
        ],
    )

    want_files = [
        "bar/BUILD.bazel",
        "foo/BUILD.bazel",
    ]

    env.expect.that_dict(actual).keys().contains_exactly(want_files)

_tests.append(_test_bzlmod_aliases_are_created_for_all_wheels)

def render_pkg_aliases_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
