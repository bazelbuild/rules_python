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

def _test_empty(env):
    actual = []
    pkg_aliases(
        name = "foo",
        actual = "repo",
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
    ]

    env.expect.that_collection(actual).contains_exactly(want)

_tests.append(_test_empty)

def pkg_aliases_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
