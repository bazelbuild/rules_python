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
"""Tests common to py_test, py_binary, and py_library rules."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "PREVENT_IMPLICIT_BUILDING_TAGS", rt_util = "util")
load("//python:defs.bzl", "PyInfo")
load("//tools/build_defs/python/tests:py_info_subject.bzl", "py_info_subject")
load("//tools/build_defs/python/tests:util.bzl", pt_util = "util")

_tests = []

def _produces_py_info_impl(ctx):
    return [PyInfo(transitive_sources = depset(ctx.files.srcs))]

_produces_py_info = rule(
    implementation = _produces_py_info_impl,
    attrs = {"srcs": attr.label_list(allow_files = True)},
)

def _test_consumes_provider(name, config):
    rt_util.helper_target(
        config.base_test_rule,
        name = name + "_subject",
        deps = [name + "_produces_py_info"],
    )
    rt_util.helper_target(
        _produces_py_info,
        name = name + "_produces_py_info",
        srcs = [rt_util.empty_file(name + "_produce.py")],
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_consumes_provider_impl,
    )

def _test_consumes_provider_impl(env, target):
    env.expect.that_target(target).provider(
        PyInfo,
        factory = py_info_subject,
    ).transitive_sources().contains("{package}/{test_name}_produce.py")

_tests.append(_test_consumes_provider)

def _test_requires_provider(name, config):
    rt_util.helper_target(
        config.base_test_rule,
        name = name + "_subject",
        deps = [name + "_nopyinfo"],
    )
    rt_util.helper_target(
        native.filegroup,
        name = name + "_nopyinfo",
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_requires_provider_impl,
        expect_failure = True,
    )

def _test_requires_provider_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("mandatory*PyInfo"),
    )

_tests.append(_test_requires_provider)

def _test_data_sets_uses_shared_library(name, config):
    rt_util.helper_target(
        config.base_test_rule,
        name = name + "_subject",
        data = [rt_util.empty_file(name + "_dso.so")],
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_data_sets_uses_shared_library_impl,
    )

def _test_data_sets_uses_shared_library_impl(env, target):
    env.expect.that_target(target).provider(
        PyInfo,
        factory = py_info_subject,
    ).uses_shared_libraries().equals(True)

_tests.append(_test_data_sets_uses_shared_library)

def _test_tags_can_be_tuple(name, config):
    # We don't use a helper because we want to ensure that value passed is
    # a tuple.
    config.base_test_rule(
        name = name + "_subject",
        tags = ("one", "two") + tuple(PREVENT_IMPLICIT_BUILDING_TAGS),
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_tags_can_be_tuple_impl,
    )

def _test_tags_can_be_tuple_impl(env, target):
    env.expect.that_target(target).tags().contains_at_least([
        "one",
        "two",
    ])

_tests.append(_test_tags_can_be_tuple)

def create_base_tests(config):
    return pt_util.create_tests(_tests, config = config)
