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
load("//python/private:whl_target_platforms.bzl", "whl_target_platforms")  # buildifier: disable=bzl-visibility

_tests = []

def _test_simple(env):
    tests = {
        "macosx_10_9_arm64": [
            struct(os = "osx", cpu = "aarch64", abi = None, target_platform = "osx_aarch64"),
        ],
        "macosx_10_9_universal2": [
            struct(os = "osx", cpu = "x86_64", abi = None, target_platform = "osx_x86_64"),
            struct(os = "osx", cpu = "aarch64", abi = None, target_platform = "osx_aarch64"),
        ],
        "manylinux1_i686.manylinux_2_17_i686": [
            struct(os = "linux", cpu = "x86_32", abi = None, target_platform = "linux_x86_32"),
        ],
        "musllinux_1_1_ppc64le": [
            struct(os = "linux", cpu = "ppc", abi = None, target_platform = "linux_ppc"),
        ],
        "win_amd64": [
            struct(os = "windows", cpu = "x86_64", abi = None, target_platform = "windows_x86_64"),
        ],
    }

    for give, want in tests.items():
        for abi in ["", "abi3", "none"]:
            got = whl_target_platforms(give, abi)
            env.expect.that_collection(got).contains_exactly(want)

_tests.append(_test_simple)

def _test_with_abi(env):
    tests = {
        "macosx_10_9_arm64": [
            struct(os = "osx", cpu = "aarch64", abi = "cp39", target_platform = "cp39_osx_aarch64"),
        ],
        "macosx_10_9_universal2": [
            struct(os = "osx", cpu = "x86_64", abi = "cp310", target_platform = "cp310_osx_x86_64"),
            struct(os = "osx", cpu = "aarch64", abi = "cp310", target_platform = "cp310_osx_aarch64"),
        ],
        "manylinux1_i686.manylinux_2_17_i686": [
            struct(os = "linux", cpu = "x86_32", abi = "cp38", target_platform = "cp38_linux_x86_32"),
        ],
        "musllinux_1_1_ppc64le": [
            struct(os = "linux", cpu = "ppc", abi = "cp311", target_platform = "cp311_linux_ppc"),
        ],
        "win_amd64": [
            struct(os = "windows", cpu = "x86_64", abi = "cp311", target_platform = "cp311_windows_x86_64"),
        ],
    }

    for give, want in tests.items():
        got = whl_target_platforms(give, want[0].abi)
        env.expect.that_collection(got).contains_exactly(want)

_tests.append(_test_with_abi)

def whl_target_platforms_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
