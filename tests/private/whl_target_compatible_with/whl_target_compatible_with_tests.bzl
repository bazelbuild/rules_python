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

""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private:parse_whl_name.bzl", "whl_target_compatible_with")  # buildifier: disable=bzl-visibility

_tests = []

def _test_compatible_with_all(env):
    got = whl_target_compatible_with("foo-1.2.3-py3-none-any.whl")
    env.expect.that_collection(got).contains_exactly([])

_tests.append(_test_compatible_with_all)

def _test_multiple_platforms(env):
    got = whl_target_compatible_with("bar-3.2.1-py3-abi3-manylinux1_x86_64.manylinux2_x86_64.whl")
    env.expect.that_collection(got).contains_exactly([
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ])

_tests.append(_test_multiple_platforms)

def _test_real_numpy_wheel(env):
    got = whl_target_compatible_with("numpy-1.26.1-pp39-pypy39_pp73-macosx_10_9_x86_64.whl")
    env.expect.that_collection(got).contains_exactly([
        "@platforms//os:osx",
        "@platforms//cpu:x86_64",
    ])

_tests.append(_test_real_numpy_wheel)

# TODO @aignas 2023-11-16: add handling for musllinux as simple linux for now.
# TODO @aignas 2023-11-16: add macos universal testcase.
# TODO @aignas 2023-11-16: add Windows testcases.
# TODO @aignas 2023-11-16: add error handling when the wheel filename is something else.

def whl_target_compatible_with_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
