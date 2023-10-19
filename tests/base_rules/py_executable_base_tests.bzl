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
"""Tests common to py_binary and py_test (executable rules)."""

load("@rules_python_internal//:rules_python_config.bzl", rp_config = "config")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//tests/base_rules:base_tests.bzl", "create_base_tests")
load("//tests/base_rules:util.bzl", "WINDOWS_ATTR", pt_util = "util")
load("//tests/support:test_platforms.bzl", "WINDOWS")

_tests = []

def _test_basic_windows(name, config):
    if rp_config.enable_pystar:
        target_compatible_with = []
    else:
        target_compatible_with = ["@platforms//:incompatible"]
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = ["main.py"],
        main = "main.py",
    )
    analysis_test(
        name = name,
        impl = _test_basic_windows_impl,
        target = name + "_subject",
        config_settings = {
            "//command_line_option:cpu": "windows_x86_64",
            "//command_line_option:crosstool_top": Label("//tests/cc:cc_toolchain_suite"),
            "//command_line_option:extra_toolchains": [str(Label("//tests/cc:all"))],
            "//command_line_option:platforms": [WINDOWS],
        },
        attr_values = {"target_compatible_with": target_compatible_with},
    )

def _test_basic_windows_impl(env, target):
    target = env.expect.that_target(target)
    target.executable().path().contains(".exe")
    target.runfiles().contains_predicate(matching.str_endswith(
        target.meta.format_str("/{name}"),
    ))
    target.runfiles().contains_predicate(matching.str_endswith(
        target.meta.format_str("/{name}.exe"),
    ))

_tests.append(_test_basic_windows)

def _test_executable_in_runfiles(name, config):
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = [name + "_subject.py"],
    )
    analysis_test(
        name = name,
        impl = _test_executable_in_runfiles_impl,
        target = name + "_subject",
        attrs = WINDOWS_ATTR,
    )

_tests.append(_test_executable_in_runfiles)

def _test_executable_in_runfiles_impl(env, target):
    if pt_util.is_windows(env):
        exe = ".exe"
    else:
        exe = ""

    env.expect.that_target(target).runfiles().contains_at_least([
        "{workspace}/{package}/{test_name}_subject" + exe,
    ])

def _test_default_main_can_be_generated(name, config):
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = [rt_util.empty_file(name + "_subject.py")],
    )
    analysis_test(
        name = name,
        impl = _test_default_main_can_be_generated_impl,
        target = name + "_subject",
    )

_tests.append(_test_default_main_can_be_generated)

def _test_default_main_can_be_generated_impl(env, target):
    env.expect.that_target(target).default_outputs().contains(
        "{package}/{test_name}_subject.py",
    )

def _test_default_main_can_have_multiple_path_segments(name, config):
    rt_util.helper_target(
        config.rule,
        name = name + "/subject",
        srcs = [name + "/subject.py"],
    )
    analysis_test(
        name = name,
        impl = _test_default_main_can_have_multiple_path_segments_impl,
        target = name + "/subject",
    )

_tests.append(_test_default_main_can_have_multiple_path_segments)

def _test_default_main_can_have_multiple_path_segments_impl(env, target):
    env.expect.that_target(target).default_outputs().contains(
        "{package}/{test_name}/subject.py",
    )

def _test_default_main_must_be_in_srcs(name, config):
    # Bazel 5 will crash with a Java stacktrace when the native Python
    # rules have an error.
    if not pt_util.is_bazel_6_or_higher():
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = ["other.py"],
    )
    analysis_test(
        name = name,
        impl = _test_default_main_must_be_in_srcs_impl,
        target = name + "_subject",
        expect_failure = True,
    )

_tests.append(_test_default_main_must_be_in_srcs)

def _test_default_main_must_be_in_srcs_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("default*does not appear in srcs"),
    )

def _test_default_main_cannot_be_ambiguous(name, config):
    # Bazel 5 will crash with a Java stacktrace when the native Python
    # rules have an error.
    if not pt_util.is_bazel_6_or_higher():
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = [name + "_subject.py", "other/{}_subject.py".format(name)],
    )
    analysis_test(
        name = name,
        impl = _test_default_main_cannot_be_ambiguous_impl,
        target = name + "_subject",
        expect_failure = True,
    )

_tests.append(_test_default_main_cannot_be_ambiguous)

def _test_default_main_cannot_be_ambiguous_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("default main*matches multiple files"),
    )

def _test_explicit_main(name, config):
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = ["custom.py"],
        main = "custom.py",
    )
    analysis_test(
        name = name,
        impl = _test_explicit_main_impl,
        target = name + "_subject",
    )

_tests.append(_test_explicit_main)

def _test_explicit_main_impl(env, target):
    # There isn't a direct way to ask what main file was selected, so we
    # rely on it being in the default outputs.
    env.expect.that_target(target).default_outputs().contains(
        "{package}/custom.py",
    )

def _test_explicit_main_cannot_be_ambiguous(name, config):
    # Bazel 5 will crash with a Java stacktrace when the native Python
    # rules have an error.
    if not pt_util.is_bazel_6_or_higher():
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = ["x/foo.py", "y/foo.py"],
        main = "foo.py",
    )
    analysis_test(
        name = name,
        impl = _test_explicit_main_cannot_be_ambiguous_impl,
        target = name + "_subject",
        expect_failure = True,
    )

_tests.append(_test_explicit_main_cannot_be_ambiguous)

def _test_explicit_main_cannot_be_ambiguous_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("foo.py*matches multiple"),
    )

def _test_files_to_build(name, config):
    rt_util.helper_target(
        config.rule,
        name = name + "_subject",
        srcs = [name + "_subject.py"],
    )
    analysis_test(
        name = name,
        impl = _test_files_to_build_impl,
        target = name + "_subject",
        attrs = WINDOWS_ATTR,
    )

_tests.append(_test_files_to_build)

def _test_files_to_build_impl(env, target):
    default_outputs = env.expect.that_target(target).default_outputs()
    if pt_util.is_windows(env):
        default_outputs.contains("{package}/{test_name}_subject.exe")
    else:
        default_outputs.contains_exactly([
            "{package}/{test_name}_subject",
            "{package}/{test_name}_subject.py",
        ])

def _test_name_cannot_end_in_py(name, config):
    # Bazel 5 will crash with a Java stacktrace when the native Python
    # rules have an error.
    if not pt_util.is_bazel_6_or_higher():
        rt_util.skip_test(name = name)
        return
    rt_util.helper_target(
        config.rule,
        name = name + "_subject.py",
        srcs = ["main.py"],
    )
    analysis_test(
        name = name,
        impl = _test_name_cannot_end_in_py_impl,
        target = name + "_subject.py",
        expect_failure = True,
    )

_tests.append(_test_name_cannot_end_in_py)

def _test_name_cannot_end_in_py_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("name must not end in*.py"),
    )

# Can't test this -- mandatory validation happens before analysis test
# can intercept it
# TODO(#1069): Once re-implemented in Starlark, modify rule logic to make this
# testable.
# def _test_srcs_is_mandatory(name, config):
#     rt_util.helper_target(
#         config.rule,
#         name = name + "_subject",
#     )
#     analysis_test(
#         name = name,
#         impl = _test_srcs_is_mandatory,
#         target = name + "_subject",
#         expect_failure = True,
#     )
#
# _tests.append(_test_srcs_is_mandatory)
#
# def _test_srcs_is_mandatory_impl(env, target):
#     env.expect.that_target(target).failures().contains_predicate(
#         matching.str_matches("mandatory*srcs"),
#     )

# =====
# You were gonna add a test at the end, weren't you?
# Nope. Please keep them sorted; put it in its alphabetical location.
# Here's the alphabet so you don't have to sing that song in your head:
# A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
# =====

def create_executable_tests(config):
    def _executable_with_srcs_wrapper(name, **kwargs):
        if not kwargs.get("srcs"):
            kwargs["srcs"] = [name + ".py"]
        config.rule(name = name, **kwargs)

    config = pt_util.struct_with(config, base_test_rule = _executable_with_srcs_wrapper)
    return pt_util.create_tests(_tests, config = config) + create_base_tests(config = config)
