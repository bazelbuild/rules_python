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
load("//python/private:whl_target_platforms.bzl", "select_whl")  # buildifier: disable=bzl-visibility

WHL_LIST = [
    struct(
        filename = f,
        url = "https://" + f,
        sha256 = "sha256://" + f,
    )
    for f in [
        "pkg-0.0.1-cp311-cp311-macosx_10_9_universal2.whl",
        "pkg-0.0.1-cp311-cp311-macosx_10_9_x86_64.whl",
        "pkg-0.0.1-cp311-cp311-macosx_11_0_arm64.whl",
        "pkg-0.0.1-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        "pkg-0.0.1-cp311-cp311-manylinux_2_17_ppc64le.manylinux2014_ppc64le.whl",
        "pkg-0.0.1-cp311-cp311-manylinux_2_17_s390x.manylinux2014_s390x.whl",
        "pkg-0.0.1-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "pkg-0.0.1-cp311-cp311-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl",
        "pkg-0.0.1-cp311-cp311-musllinux_1_1_aarch64.whl",
        "pkg-0.0.1-cp311-cp311-musllinux_1_1_i686.whl",
        "pkg-0.0.1-cp311-cp311-musllinux_1_1_ppc64le.whl",
        "pkg-0.0.1-cp311-cp311-musllinux_1_1_s390x.whl",
        "pkg-0.0.1-cp311-cp311-musllinux_1_1_x86_64.whl",
        "pkg-0.0.1-cp311-cp311-win32.whl",
        "pkg-0.0.1-cp311-cp311-win_amd64.whl",
        "pkg-0.0.1-cp37-cp37m-macosx_10_9_x86_64.whl",
        "pkg-0.0.1-cp37-cp37m-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        "pkg-0.0.1-cp37-cp37m-manylinux_2_17_ppc64le.manylinux2014_ppc64le.whl",
        "pkg-0.0.1-cp37-cp37m-manylinux_2_17_s390x.manylinux2014_s390x.whl",
        "pkg-0.0.1-cp37-cp37m-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "pkg-0.0.1-cp37-cp37m-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl",
        "pkg-0.0.1-cp37-cp37m-musllinux_1_1_aarch64.whl",
        "pkg-0.0.1-cp37-cp37m-musllinux_1_1_i686.whl",
        "pkg-0.0.1-cp37-cp37m-musllinux_1_1_ppc64le.whl",
        "pkg-0.0.1-cp37-cp37m-musllinux_1_1_s390x.whl",
        "pkg-0.0.1-cp37-cp37m-musllinux_1_1_x86_64.whl",
        "pkg-0.0.1-cp37-cp37m-win32.whl",
        "pkg-0.0.1-cp37-cp37m-win_amd64.whl",
        "pkg-0.0.1-cp39-cp39-macosx_10_9_universal2.whl",
        "pkg-0.0.1-cp39-cp39-macosx_10_9_x86_64.whl",
        "pkg-0.0.1-cp39-cp39-macosx_11_0_arm64.whl",
        "pkg-0.0.1-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        "pkg-0.0.1-cp39-cp39-manylinux_2_17_ppc64le.manylinux2014_ppc64le.whl",
        "pkg-0.0.1-cp39-cp39-manylinux_2_17_s390x.manylinux2014_s390x.whl",
        "pkg-0.0.1-cp39-cp39-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "pkg-0.0.1-cp39-cp39-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl",
        "pkg-0.0.1-cp39-cp39-musllinux_1_1_aarch64.whl",
        "pkg-0.0.1-cp39-cp39-musllinux_1_1_i686.whl",
        "pkg-0.0.1-cp39-cp39-musllinux_1_1_ppc64le.whl",
        "pkg-0.0.1-cp39-cp39-musllinux_1_1_s390x.whl",
        "pkg-0.0.1-cp39-cp39-musllinux_1_1_x86_64.whl",
        "pkg-0.0.1-cp39-cp39-win32.whl",
        "pkg-0.0.1-cp39-cp39-win_amd64.whl",
        "pkg-0.0.1-py3-abi3-any.whl",
        "pkg-0.0.1-py3-none-any.whl",
    ]
]

def _match(env, got, want_filename):
    if want_filename:
        env.expect.that_str(got.filename).equals(want_filename)
        env.expect.that_str(got.sha256).equals("sha256://" + want_filename)
        env.expect.that_str(got.url).equals("https://" + want_filename)
    else:
        env.expect.that_int(got).equals(None)

_tests = []

def _test_selecting(env):
    got = select_whl(whls = WHL_LIST, want_abis = ["none"], want_platform = "ignored")
    _match(env, got, "pkg-0.0.1-py3-none-any.whl")

    got = select_whl(whls = WHL_LIST, want_abis = ["abi3"], want_platform = "ignored")
    _match(env, got, "pkg-0.0.1-py3-abi3-any.whl")

    # Check the selection failure
    got = select_whl(whls = WHL_LIST, want_abis = ["cp39"], want_platform = "does-not-exist")
    _match(env, got, None)

    # Check we match the ABI and not the py version
    got = select_whl(whls = WHL_LIST, want_abis = ["cp37m"], want_platform = "linux_x86_64")
    _match(env, got, "pkg-0.0.1-cp37-cp37m-manylinux_2_17_x86_64.manylinux2014_x86_64.whl")

    # Check we can select a filename with many platform tags
    got = select_whl(whls = WHL_LIST, want_abis = ["cp39"], want_platform = "linux_x86_32")
    _match(env, got, "pkg-0.0.1-cp39-cp39-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl")

    # Check that we prefer the specific wheel
    got = select_whl(whls = WHL_LIST, want_abis = ["cp311"], want_platform = "osx_x86_64")
    _match(env, got, "pkg-0.0.1-cp311-cp311-macosx_10_9_x86_64.whl")

    got = select_whl(whls = WHL_LIST, want_abis = ["cp311"], want_platform = "osx_aarch64")
    _match(env, got, "pkg-0.0.1-cp311-cp311-macosx_11_0_arm64.whl")

    # Check that we can use the universal2 if the arm wheel is not available
    got = select_whl(whls = [w for w in WHL_LIST if "arm64" not in w.filename], want_abis = ["cp311"], want_platform = "osx_aarch64")
    _match(env, got, "pkg-0.0.1-cp311-cp311-macosx_10_9_universal2.whl")

    # Check we prefer platform specific wheels
    got = select_whl(whls = WHL_LIST, want_abis = ["none", "abi3", "cp39"], want_platform = "linux_x86_64")
    _match(env, got, "pkg-0.0.1-cp39-cp39-manylinux_2_17_x86_64.manylinux2014_x86_64.whl")

_tests.append(_test_selecting)

def select_whl_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
