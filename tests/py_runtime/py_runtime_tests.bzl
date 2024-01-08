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
"""Starlark tests for py_runtime rule."""

load("@rules_python_internal//:rules_python_config.bzl", "config")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python:py_runtime.bzl", "py_runtime")
load("//python:py_runtime_info.bzl", "PyRuntimeInfo")
load("//tests:py_runtime_info_subject.bzl", "py_runtime_info_subject")
load("//tests/base_rules:util.bzl", br_util = "util")

_tests = []

_SKIP_TEST = {
    "target_compatible_with": ["@platforms//:incompatible"],
}

def _simple_binary_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(output, "", is_executable = True)
    return [DefaultInfo(
        executable = output,
        runfiles = ctx.runfiles(ctx.files.data),
    )]

_simple_binary = rule(
    implementation = _simple_binary_impl,
    attrs = {"data": attr.label_list(allow_files = True)},
    executable = True,
)

def _test_bootstrap_template(name):
    # The bootstrap_template arg isn't present in older Bazel versions, so
    # we have to conditionally pass the arg and mark the test incompatible.
    if config.enable_pystar:
        py_runtime_kwargs = {"bootstrap_template": "bootstrap.txt"}
        attr_values = {}
    else:
        py_runtime_kwargs = {}
        attr_values = _SKIP_TEST

    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        interpreter_path = "/py",
        python_version = "PY3",
        **py_runtime_kwargs
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_bootstrap_template_impl,
        attr_values = attr_values,
    )

def _test_bootstrap_template_impl(env, target):
    env.expect.that_target(target).provider(
        PyRuntimeInfo,
        factory = py_runtime_info_subject,
    ).bootstrap_template().path().contains("bootstrap.txt")

_tests.append(_test_bootstrap_template)

def _test_cannot_have_both_inbuild_and_system_interpreter(name):
    if br_util.is_bazel_6_or_higher():
        py_runtime_kwargs = {
            "interpreter": "fake_interpreter",
            "interpreter_path": "/some/path",
        }
        attr_values = {}
    else:
        py_runtime_kwargs = {
            "interpreter_path": "/some/path",
        }
        attr_values = _SKIP_TEST
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        python_version = "PY3",
        **py_runtime_kwargs
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_cannot_have_both_inbuild_and_system_interpreter_impl,
        expect_failure = True,
        attr_values = attr_values,
    )

def _test_cannot_have_both_inbuild_and_system_interpreter_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("one of*interpreter*interpreter_path"),
    )

_tests.append(_test_cannot_have_both_inbuild_and_system_interpreter)

def _test_cannot_specify_files_for_system_interpreter(name):
    if br_util.is_bazel_6_or_higher():
        py_runtime_kwargs = {"files": ["foo.txt"]}
        attr_values = {}
    else:
        py_runtime_kwargs = {}
        attr_values = _SKIP_TEST
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        interpreter_path = "/foo",
        python_version = "PY3",
        **py_runtime_kwargs
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_cannot_specify_files_for_system_interpreter_impl,
        expect_failure = True,
        attr_values = attr_values,
    )

def _test_cannot_specify_files_for_system_interpreter_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("files*must be empty"),
    )

_tests.append(_test_cannot_specify_files_for_system_interpreter)

def _test_coverage_tool_executable(name):
    if br_util.is_bazel_6_or_higher():
        py_runtime_kwargs = {
            "coverage_tool": name + "_coverage_tool",
        }
        attr_values = {}
    else:
        py_runtime_kwargs = {}
        attr_values = _SKIP_TEST

    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        python_version = "PY3",
        interpreter_path = "/bogus",
        **py_runtime_kwargs
    )
    rt_util.helper_target(
        _simple_binary,
        name = name + "_coverage_tool",
        data = ["coverage_file1.txt", "coverage_file2.txt"],
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_coverage_tool_executable_impl,
        attr_values = attr_values,
    )

def _test_coverage_tool_executable_impl(env, target):
    info = env.expect.that_target(target).provider(PyRuntimeInfo, factory = py_runtime_info_subject)
    info.coverage_tool().short_path_equals("{package}/{test_name}_coverage_tool")
    info.coverage_files().contains_exactly([
        "{package}/{test_name}_coverage_tool",
        "{package}/coverage_file1.txt",
        "{package}/coverage_file2.txt",
    ])

_tests.append(_test_coverage_tool_executable)

def _test_coverage_tool_plain_files(name):
    if br_util.is_bazel_6_or_higher():
        py_runtime_kwargs = {
            "coverage_tool": name + "_coverage_tool",
        }
        attr_values = {}
    else:
        py_runtime_kwargs = {}
        attr_values = _SKIP_TEST
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        python_version = "PY3",
        interpreter_path = "/bogus",
        **py_runtime_kwargs
    )
    rt_util.helper_target(
        native.filegroup,
        name = name + "_coverage_tool",
        srcs = ["coverage_tool.py"],
        data = ["coverage_file1.txt", "coverage_file2.txt"],
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_coverage_tool_plain_files_impl,
        attr_values = attr_values,
    )

def _test_coverage_tool_plain_files_impl(env, target):
    info = env.expect.that_target(target).provider(PyRuntimeInfo, factory = py_runtime_info_subject)
    info.coverage_tool().short_path_equals("{package}/coverage_tool.py")
    info.coverage_files().contains_exactly([
        "{package}/coverage_tool.py",
        "{package}/coverage_file1.txt",
        "{package}/coverage_file2.txt",
    ])

_tests.append(_test_coverage_tool_plain_files)

def _test_in_build_interpreter(name):
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        interpreter = "fake_interpreter",
        python_version = "PY3",
        files = ["file1.txt"],
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_in_build_interpreter_impl,
    )

def _test_in_build_interpreter_impl(env, target):
    info = env.expect.that_target(target).provider(PyRuntimeInfo, factory = py_runtime_info_subject)
    info.python_version().equals("PY3")
    info.files().contains_predicate(matching.file_basename_equals("file1.txt"))
    info.interpreter().path().contains("fake_interpreter")

_tests.append(_test_in_build_interpreter)

def _test_must_have_either_inbuild_or_system_interpreter(name):
    if br_util.is_bazel_6_or_higher():
        py_runtime_kwargs = {}
        attr_values = {}
    else:
        py_runtime_kwargs = {
            "interpreter_path": "/some/path",
        }
        attr_values = _SKIP_TEST
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        python_version = "PY3",
        **py_runtime_kwargs
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_must_have_either_inbuild_or_system_interpreter_impl,
        expect_failure = True,
        attr_values = attr_values,
    )

def _test_must_have_either_inbuild_or_system_interpreter_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("one of*interpreter*interpreter_path"),
    )

_tests.append(_test_must_have_either_inbuild_or_system_interpreter)

def _test_system_interpreter(name):
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        interpreter_path = "/system/python",
        python_version = "PY3",
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_system_interpreter_impl,
    )

def _test_system_interpreter_impl(env, target):
    env.expect.that_target(target).provider(
        PyRuntimeInfo,
        factory = py_runtime_info_subject,
    ).interpreter_path().equals("/system/python")

_tests.append(_test_system_interpreter)

def _test_system_interpreter_must_be_absolute(name):
    # Bazel 5.4 will entirely crash when an invalid interpreter_path
    # is given.
    if br_util.is_bazel_6_or_higher():
        py_runtime_kwargs = {"interpreter_path": "relative/path"}
        attr_values = {}
    else:
        py_runtime_kwargs = {"interpreter_path": "/junk/value/for/bazel5.4"}
        attr_values = _SKIP_TEST
    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        python_version = "PY3",
        **py_runtime_kwargs
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_system_interpreter_must_be_absolute_impl,
        expect_failure = True,
        attr_values = attr_values,
    )

def _test_system_interpreter_must_be_absolute_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("must be*absolute"),
    )

_tests.append(_test_system_interpreter_must_be_absolute)

def _test_interpreter_sh_binary_target(name):
    rt_util.helper_target(
        native.sh_binary,
        name = "built_interpreter",
        srcs = ["pretend_binary"],
    )

    rt_util.helper_target(
        py_runtime,
        name = name + "_subject",
        interpreter = ":built_interpreter",
        python_version = "PY3",
    )
    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_interpreter_sh_binary_target_impl,
    )

def _test_interpreter_sh_binary_target_impl(env, target):
    env.expect.that_target(target).provider(
        PyRuntimeInfo,
        factory = py_runtime_info_subject,
    ).interpreter_path().equals(None)

_tests.append(_test_interpreter_sh_binary_target)

def py_runtime_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
