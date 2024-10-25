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

""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private/pypi:whl_library_targets.bzl", "whl_library_targets")  # buildifier: disable=bzl-visibility

_tests = []

def _test_filegroups(env):
    calls = []

    def glob(match, *, allow_empty):
        env.expect.that_bool(allow_empty).equals(True)
        return match

    whl_library_targets(
        name = "dummy",
        native = struct(
            filegroup = lambda **kwargs: calls.append(kwargs),
            glob = glob,
        ),
    )

    env.expect.that_collection(calls).contains_exactly([
        {
            "name": "dist_info",
            "srcs": ["site-packages/*.dist-info/**"],
        },
        {
            "name": "data",
            "srcs": ["data/**"],
        },
    ])

_tests.append(_test_filegroups)

def whl_library_targets_test_suite(name):
    """create the test suite.

    args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
