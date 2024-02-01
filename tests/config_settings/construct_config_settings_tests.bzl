# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Tests for construction of Python version matching config settings."""

load("@//python:versions.bzl", "MINOR_MAPPING")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "subjects")
load("@rules_testing//lib:util.bzl", rt_util = "util")

_tests = []

def _subject_impl(ctx):
    _ = ctx  # @unused
    return [DefaultInfo()]

_subject = rule(
    implementation = _subject_impl,
    attrs = {
        "match_micro": attr.string(),
        "match_minor": attr.string(),
        "no_match": attr.string(),
        "no_match_micro": attr.string(),
    },
)

def _test_minor_version_matching(name):
    rt_util.helper_target(
        _subject,
        name = name + "_subject",
        match_minor = select({
            "//python/config_settings:is_python_3.11": "matched-3.11",
            "//conditions:default": "matched-default",
        }),
        match_micro = select({
            "//python/config_settings:is_python_3.11": "matched-3.11",
            "//conditions:default": "matched-default",
        }),
        no_match = select({
            "//python/config_settings:is_python_3.12": "matched-3.12",
            "//conditions:default": "matched-default",
        }),
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_minor_version_matching_impl,
        config_settings = {
            str(Label("//python/config_settings:python_version")): "3.11.1",
        },
    )

def _test_minor_version_matching_impl(env, target):
    target = env.expect.that_target(target)
    target.attr("match_minor", factory = subjects.str).equals(
        "matched-3.11",
    )
    target.attr("match_micro", factory = subjects.str).equals(
        "matched-3.11",
    )
    target.attr("no_match", factory = subjects.str).equals(
        "matched-default",
    )

_tests.append(_test_minor_version_matching)

def _test_latest_micro_version_matching(name):
    rt_util.helper_target(
        _subject,
        name = name + "_subject",
        match_minor = select({
            "//python/config_settings:is_python_3.12": "matched-3.12",
            "//conditions:default": "matched-default",
        }),
        match_micro = select({
            "//python/config_settings:is_python_" + MINOR_MAPPING["3.12"]: "matched-3.12",
            "//conditions:default": "matched-default",
        }),
        no_match_micro = select({
            "//python/config_settings:is_python_3.12.0": "matched-3.12",
            "//conditions:default": "matched-default",
        }),
        no_match = select({
            "//python/config_settings:is_python_" + MINOR_MAPPING["3.11"]: "matched-3.11",
            "//conditions:default": "matched-default",
        }),
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_latest_micro_version_matching_impl,
        config_settings = {
            str(Label("//python/config_settings:python_version")): "3.12",
        },
    )

def _test_latest_micro_version_matching_impl(env, target):
    target = env.expect.that_target(target)
    target.attr("match_minor", factory = subjects.str).equals(
        "matched-3.12",
    )
    target.attr("match_micro", factory = subjects.str).equals(
        "matched-3.12",
    )
    target.attr("no_match_micro", factory = subjects.str).equals(
        "matched-default",
    )
    target.attr("no_match", factory = subjects.str).equals(
        "matched-default",
    )

_tests.append(_test_latest_micro_version_matching)

def construct_config_settings_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
