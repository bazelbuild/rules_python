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
load("//python/private:target_platform.bzl", "target_platform")  # buildifier: disable=bzl-visibility

_tests = []

def _test_simple(env):
    tests = {
        "macosx_10_9_arm64": [
            struct(os = "osx", cpu = "aarch64"),
        ],
        "macosx_10_9_universal2": [
            struct(os = "osx", cpu = "x86_64"),
            struct(os = "osx", cpu = "aarch64"),
        ],
        "manylinux1_i686.manylinux_2_17_i686": [
            struct(os = "linux", cpu = "x86_32"),
        ],
        "musllinux_1_1_ppc64le": [
            struct(os = "linux", cpu = "ppc"),
        ],
        "win_amd64": [
            struct(os = "windows", cpu = "x86_64"),
        ],
    }

    for give, want in tests.items():
        got = target_platform(give)
        env.expect.that_collection(got).contains_exactly(want)

_tests.append(_test_simple)

def target_platform_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
