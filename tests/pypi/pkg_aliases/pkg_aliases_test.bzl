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

"""pkg_aliases tests"""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load(
    "//python/private/pypi:pkg_aliases.bzl",
    "pkg_aliases",
)  # buildifier: disable=bzl-visibility

_tests = []

def _test_legacy_aliases(env):
    actual = []
    pkg_aliases(
        name = "foo",
        actual = "repo",
        native = struct(
            alias = lambda **kwargs: actual.append(kwargs),
        ),
        extra_aliases = ["my_special"],
    )

    # buildifier: disable=unsorted-dict-items
    want = [
        {
            "name": "foo",
            "actual": ":pkg",
        },
        {
            "name": "pkg",
            "actual": "@repo//:pkg",
        },
        {
            "name": "whl",
            "actual": "@repo//:whl",
        },
        {
            "name": "data",
            "actual": "@repo//:data",
        },
        {
            "name": "dist_info",
            "actual": "@repo//:dist_info",
        },
        {
            "name": "my_special",
            "actual": "@repo//:my_special",
        },
    ]

    env.expect.that_collection(actual).contains_exactly(want)

_tests.append(_test_legacy_aliases)

def _test_config_setting_aliases(env):
    # Use this function as it is used in pip_repository
    actual = []
    actual_no_match_error = []

    def mock_select(value, no_match_error = None):
        actual_no_match_error.append(no_match_error)
        env.expect.that_str(no_match_error).equals("""\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
wheels available for this wheel. This wheel supports the following Python
configuration settings:
    //:my_config_setting

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    rules_python//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
""")
        return struct(value = value, no_match_error = no_match_error != None)

    pkg_aliases(
        name = "bar_baz",
        actual = {
            "//:my_config_setting": "bar_baz_repo",
        },
        extra_aliases = ["my_special"],
        native = struct(
            alias = lambda **kwargs: actual.append(kwargs),
        ),
        select = mock_select,
    )

    # buildifier: disable=unsorted-dict-items
    want = [
        {
            "name": "bar_baz",
            "actual": ":pkg",
        },
        {
            "name": "pkg",
            "actual": struct(
                value = {
                    "//:my_config_setting": "@bar_baz_repo//:pkg",
                },
                no_match_error = True,
            ),
        },
        {
            "name": "whl",
            "actual": struct(
                value = {
                    "//:my_config_setting": "@bar_baz_repo//:whl",
                },
                no_match_error = True,
            ),
        },
        {
            "name": "data",
            "actual": struct(
                value = {
                    "//:my_config_setting": "@bar_baz_repo//:data",
                },
                no_match_error = True,
            ),
        },
        {
            "name": "dist_info",
            "actual": struct(
                value = {
                    "//:my_config_setting": "@bar_baz_repo//:dist_info",
                },
                no_match_error = True,
            ),
        },
        {
            "name": "my_special",
            "actual": struct(
                value = {
                    "//:my_config_setting": "@bar_baz_repo//:my_special",
                },
                no_match_error = True,
            ),
        },
    ]
    env.expect.that_collection(actual).contains_exactly(want)

_tests.append(_test_config_setting_aliases)

def _test_group_aliases(env):
    # Use this function as it is used in pip_repository
    actual = []

    pkg_aliases(
        name = "foo",
        actual = "repo",
        group_name = "my_group",
        native = struct(
            alias = lambda **kwargs: actual.append(kwargs),
        ),
    )

    # buildifier: disable=unsorted-dict-items
    want = [
        {
            "name": "foo",
            "actual": ":pkg",
        },
        {
            "name": "_pkg",
            "actual": "@repo//:pkg",
            "visibility": ["//_groups:__subpackages__"],
        },
        {
            "name": "_whl",
            "actual": "@repo//:whl",
            "visibility": ["//_groups:__subpackages__"],
        },
        {
            "name": "data",
            "actual": "@repo//:data",
        },
        {
            "name": "dist_info",
            "actual": "@repo//:dist_info",
        },
        {
            "name": "pkg",
            "actual": "//_groups:my_group_pkg",
        },
        {
            "name": "whl",
            "actual": "//_groups:my_group_whl",
        },
    ]
    env.expect.that_collection(actual).contains_exactly(want)

_tests.append(_test_group_aliases)

def pkg_aliases_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
