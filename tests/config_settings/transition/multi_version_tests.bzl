# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Tests for py_test."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python/config_settings:transition.bzl", py_binary_transitioned = "py_binary", py_test_transitioned = "py_test")

# NOTE @aignas 2024-06-04: we are using here something that is registered in the MODULE.Bazel
# and if you find tests failing, it could be because of the toolchain resolution issues here.
#
# If the toolchain is not resolved then you will have a weird message telling
# you that your transition target does not have a PyRuntime provider, which is
# caused by there not being a toolchain detected for the target.
_PYTHON_VERSION = "3.11"

_tests = []

def _test_py_test_with_transition(name):
    rt_util.helper_target(
        py_test_transitioned,
        name = name + "_subject",
        srcs = [name + "_subject.py"],
        python_version = _PYTHON_VERSION,
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_py_test_with_transition_impl,
    )

def _test_py_test_with_transition_impl(env, target):
    # Nothing to assert; we just want to make sure it builds
    _ = env, target  # @unused

_tests.append(_test_py_test_with_transition)

def _test_py_binary_with_transition(name):
    rt_util.helper_target(
        py_binary_transitioned,
        name = name + "_subject",
        srcs = [name + "_subject.py"],
        python_version = _PYTHON_VERSION,
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_py_binary_with_transition_impl,
    )

def _test_py_binary_with_transition_impl(env, target):
    # Nothing to assert; we just want to make sure it builds
    _ = env, target  # @unused

_tests.append(_test_py_binary_with_transition)

def multi_version_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
