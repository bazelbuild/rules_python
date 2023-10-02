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
"""Starlark tests for py_runtime_pair rule."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python:py_runtime.bzl", "py_runtime")
load("//python:py_runtime_pair.bzl", "py_runtime_pair")
load("//tests:py_runtime_info_subject.bzl", "py_runtime_info_subject")

_tests = []

def _test_basic(name):
    rt_util.helper_target(
        py_runtime,
        name = name + "_runtime",
        interpreter = "fake_interpreter",
        python_version = "PY3",
        files = ["file1.txt"],
    )
    rt_util.helper_target(
        py_runtime_pair,
        name = name + "_subject",
        py3_runtime = name + "_runtime",
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_basic_impl,
    )

def _test_basic_impl(env, target):
    toolchain = env.expect.that_target(target).provider(
        platform_common.ToolchainInfo,
        factory = lambda value, meta: subjects.struct(
            value,
            meta = meta,
            attrs = {
                "py3_runtime": py_runtime_info_subject,
            },
        ),
    )
    toolchain.py3_runtime().python_version().equals("PY3")
    toolchain.py3_runtime().files().contains_predicate(matching.file_basename_equals("file1.txt"))
    toolchain.py3_runtime().interpreter().path().contains("fake_interpreter")

_tests.append(_test_basic)

def py_runtime_pair_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
