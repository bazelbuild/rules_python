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
"""Test for py_wheel."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python:packaging.bzl", "py_wheel")

_tests = []

def _test_metadata(name):
    rt_util.helper_target(
        py_wheel,
        name = name + "_subject",
        distribution = "mydist_" + name,
        version = "0.0.0",
    )
    analysis_test(
        name = name,
        impl = _test_metadata_impl,
        target = name + "_subject",
    )

def _test_metadata_impl(env, target):
    action = env.expect.that_target(target).action_generating(
        "{package}/{name}.metadata.txt",
    )
    action.content().split("\n").contains_exactly([
        env.expect.meta.format_str("Name: mydist_{test_name}"),
        "Metadata-Version: 2.1",
        "",
    ])

_tests.append(_test_metadata)

def _test_content_type_from_attr(name):
    rt_util.helper_target(
        py_wheel,
        name = name + "_subject",
        distribution = "mydist_" + name,
        version = "0.0.0",
        description_content_type = "text/x-rst",
    )
    analysis_test(
        name = name,
        impl = _test_content_type_from_attr_impl,
        target = name + "_subject",
    )

def _test_content_type_from_attr_impl(env, target):
    action = env.expect.that_target(target).action_generating(
        "{package}/{name}.metadata.txt",
    )
    action.content().split("\n").contains(
        "Description-Content-Type: text/x-rst",
    )

_tests.append(_test_content_type_from_attr)

def _test_content_type_from_description(name):
    rt_util.helper_target(
        py_wheel,
        name = name + "_subject",
        distribution = "mydist_" + name,
        version = "0.0.0",
        description_file = "desc.md",
    )
    analysis_test(
        name = name,
        impl = _test_content_type_from_description_impl,
        target = name + "_subject",
    )

def _test_content_type_from_description_impl(env, target):
    action = env.expect.that_target(target).action_generating(
        "{package}/{name}.metadata.txt",
    )
    action.content().split("\n").contains(
        "Description-Content-Type: text/markdown",
    )

_tests.append(_test_content_type_from_description)

def py_wheel_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
