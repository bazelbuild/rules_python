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

"""Tests for precompiling behavior."""

load("@rules_python_internal//:rules_python_config.bzl", rp_config = "config")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python:py_binary.bzl", "py_binary")
load("//python:py_info.bzl", "PyInfo")
load("//python:py_library.bzl", "py_library")
load("//python:py_test.bzl", "py_test")
load("//tests/base_rules:py_info_subject.bzl", "py_info_subject")
load(
    "//tests/support:support.bzl",
    "CC_TOOLCHAIN",
    "EXEC_TOOLS_TOOLCHAIN",
    "PLATFORM_TOOLCHAIN",
    "PRECOMPILE",
    "PRECOMPILE_ADD_TO_RUNFILES",
    "PRECOMPILE_SOURCE_RETENTION",
)

_TEST_TOOLCHAINS = [PLATFORM_TOOLCHAIN, CC_TOOLCHAIN]

_tests = []

def _test_precompile_enabled_setup(name, py_rule, **kwargs):
    if not rp_config.enable_pystar:
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        py_rule,
        name = name + "_subject",
        precompile = "enabled",
        srcs = ["main.py"],
        deps = [name + "_lib"],
        **kwargs
    )
    rt_util.helper_target(
        py_library,
        name = name + "_lib",
        srcs = ["lib.py"],
        precompile = "enabled",
    )
    analysis_test(
        name = name,
        impl = _test_precompile_enabled_impl,
        target = name + "_subject",
        config_settings = {
            "//command_line_option:extra_toolchains": _TEST_TOOLCHAINS,
            EXEC_TOOLS_TOOLCHAIN: "enabled",
        },
    )

def _test_precompile_enabled_impl(env, target):
    target = env.expect.that_target(target)
    runfiles = target.runfiles()
    runfiles.contains_predicate(
        matching.str_matches("__pycache__/main.fakepy-45.pyc"),
    )
    runfiles.contains_predicate(
        matching.str_matches("/main.py"),
    )
    target.default_outputs().contains_at_least_predicates([
        matching.file_path_matches("__pycache__/main.fakepy-45.pyc"),
        matching.file_path_matches("/main.py"),
    ])
    py_info = target.provider(PyInfo, factory = py_info_subject)
    py_info.direct_pyc_files().contains_exactly([
        "{package}/__pycache__/main.fakepy-45.pyc",
    ])
    py_info.transitive_pyc_files().contains_exactly([
        "{package}/__pycache__/main.fakepy-45.pyc",
        "{package}/__pycache__/lib.fakepy-45.pyc",
    ])

def _test_precompile_enabled_py_binary(name):
    _test_precompile_enabled_setup(name = name, py_rule = py_binary, main = "main.py")

_tests.append(_test_precompile_enabled_py_binary)

def _test_precompile_enabled_py_test(name):
    _test_precompile_enabled_setup(name = name, py_rule = py_test, main = "main.py")

_tests.append(_test_precompile_enabled_py_test)

def _test_precompile_enabled_py_library(name):
    _test_precompile_enabled_setup(name = name, py_rule = py_library)

_tests.append(_test_precompile_enabled_py_library)

def _test_pyc_only(name):
    if not rp_config.enable_pystar:
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        py_binary,
        name = name + "_subject",
        precompile = "enabled",
        srcs = ["main.py"],
        main = "main.py",
        precompile_source_retention = "omit_source",
    )
    analysis_test(
        name = name,
        impl = _test_pyc_only_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": _TEST_TOOLCHAINS,
            ##PRECOMPILE_SOURCE_RETENTION: "omit_source",
            EXEC_TOOLS_TOOLCHAIN: "enabled",
        },
        target = name + "_subject",
    )

_tests.append(_test_pyc_only)

def _test_pyc_only_impl(env, target):
    target = env.expect.that_target(target)
    runfiles = target.runfiles()
    runfiles.contains_predicate(
        matching.str_matches("/main.pyc"),
    )
    runfiles.not_contains_predicate(
        matching.str_endswith("/main.py"),
    )
    target.default_outputs().contains_at_least_predicates([
        matching.file_path_matches("/main.pyc"),
    ])
    target.default_outputs().not_contains_predicate(
        matching.file_basename_equals("main.py"),
    )

def _test_precompile_if_generated(name):
    if not rp_config.enable_pystar:
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        py_binary,
        name = name + "_subject",
        srcs = [
            "main.py",
            rt_util.empty_file("generated1.py"),
        ],
        main = "main.py",
        precompile = "if_generated_source",
    )
    analysis_test(
        name = name,
        impl = _test_precompile_if_generated_impl,
        target = name + "_subject",
        config_settings = {
            "//command_line_option:extra_toolchains": _TEST_TOOLCHAINS,
            EXEC_TOOLS_TOOLCHAIN: "enabled",
        },
    )

_tests.append(_test_precompile_if_generated)

def _test_precompile_if_generated_impl(env, target):
    target = env.expect.that_target(target)
    runfiles = target.runfiles()
    runfiles.contains_predicate(
        matching.str_matches("/__pycache__/generated1.fakepy-45.pyc"),
    )
    runfiles.not_contains_predicate(
        matching.str_matches("main.*pyc"),
    )
    target.default_outputs().contains_at_least_predicates([
        matching.file_path_matches("/__pycache__/generated1.fakepy-45.pyc"),
    ])
    target.default_outputs().not_contains_predicate(
        matching.file_path_matches("main.*pyc"),
    )

def _test_omit_source_if_generated_source(name):
    if not rp_config.enable_pystar:
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        py_binary,
        name = name + "_subject",
        srcs = [
            "main.py",
            rt_util.empty_file("generated2.py"),
        ],
        main = "main.py",
        precompile = "enabled",
    )
    analysis_test(
        name = name,
        impl = _test_omit_source_if_generated_source_impl,
        target = name + "_subject",
        config_settings = {
            "//command_line_option:extra_toolchains": _TEST_TOOLCHAINS,
            PRECOMPILE_SOURCE_RETENTION: "omit_if_generated_source",
            EXEC_TOOLS_TOOLCHAIN: "enabled",
        },
    )

_tests.append(_test_omit_source_if_generated_source)

def _test_omit_source_if_generated_source_impl(env, target):
    target = env.expect.that_target(target)
    runfiles = target.runfiles()
    runfiles.contains_predicate(
        matching.str_matches("/generated2.pyc"),
    )
    runfiles.contains_predicate(
        matching.str_matches("__pycache__/main.fakepy-45.pyc"),
    )
    target.default_outputs().contains_at_least_predicates([
        matching.file_path_matches("generated2.pyc"),
    ])
    target.default_outputs().contains_predicate(
        matching.file_path_matches("__pycache__/main.fakepy-45.pyc"),
    )

def _test_precompile_add_to_runfiles_decided_elsewhere(name):
    if not rp_config.enable_pystar:
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        py_binary,
        name = name + "_binary",
        srcs = ["bin.py"],
        main = "bin.py",
        deps = [name + "_lib"],
        pyc_collection = "include_pyc",
    )
    rt_util.helper_target(
        py_library,
        name = name + "_lib",
        srcs = ["lib.py"],
    )
    analysis_test(
        name = name,
        impl = _test_precompile_add_to_runfiles_decided_elsewhere_impl,
        targets = {
            "binary": name + "_binary",
            "library": name + "_lib",
        },
        config_settings = {
            "//command_line_option:extra_toolchains": _TEST_TOOLCHAINS,
            PRECOMPILE_ADD_TO_RUNFILES: "decided_elsewhere",
            PRECOMPILE: "enabled",
            EXEC_TOOLS_TOOLCHAIN: "enabled",
        },
    )

_tests.append(_test_precompile_add_to_runfiles_decided_elsewhere)

def _test_precompile_add_to_runfiles_decided_elsewhere_impl(env, targets):
    env.expect.that_target(targets.binary).runfiles().contains_at_least([
        "{workspace}/tests/base_rules/precompile/__pycache__/bin.fakepy-45.pyc",
        "{workspace}/tests/base_rules/precompile/__pycache__/lib.fakepy-45.pyc",
        "{workspace}/tests/base_rules/precompile/bin.py",
        "{workspace}/tests/base_rules/precompile/lib.py",
    ])

    env.expect.that_target(targets.library).runfiles().contains_exactly([
        "{workspace}/tests/base_rules/precompile/lib.py",
    ])

def _test_precompiler_action(name):
    if not rp_config.enable_pystar:
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        py_binary,
        name = name + "_subject",
        srcs = ["main2.py"],
        main = "main2.py",
        precompile = "enabled",
        precompile_optimize_level = 2,
        precompile_invalidation_mode = "unchecked_hash",
    )
    analysis_test(
        name = name,
        impl = _test_precompiler_action_impl,
        target = name + "_subject",
        config_settings = {
            "//command_line_option:extra_toolchains": _TEST_TOOLCHAINS,
            EXEC_TOOLS_TOOLCHAIN: "enabled",
        },
    )

_tests.append(_test_precompiler_action)

def _test_precompiler_action_impl(env, target):
    #env.expect.that_target(target).runfiles().contains_exactly([])
    action = env.expect.that_target(target).action_named("PyCompile")
    action.contains_flag_values([
        ("--optimize", "2"),
        ("--python_version", "4.5"),
        ("--invalidation_mode", "unchecked_hash"),
    ])
    action.has_flags_specified(["--src", "--pyc", "--src_name"])
    action.env().contains_at_least({
        "PYTHONHASHSEED": "0",
        "PYTHONNOUSERSITE": "1",
        "PYTHONSAFEPATH": "1",
    })

def precompile_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
