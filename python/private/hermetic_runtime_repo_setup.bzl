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
"""Setup a python-build-standalone based toolchain."""

load("@rules_cc//cc:defs.bzl", "cc_import", "cc_library")
load("@rules_python//python:py_runtime.bzl", "py_runtime")
load("@rules_python//python:py_runtime_pair.bzl", "py_runtime_pair")
load("@rules_python//python/cc:py_cc_toolchain.bzl", "py_cc_toolchain")
load("@rules_python//python/private:py_exec_tools_toolchain.bzl", "py_exec_tools_toolchain")

def define_hermetic_runtime_toolchain_impl(
        *,
        name,
        extra_files_glob_include,
        extra_files_glob_exclude,
        python_version,
        python_bin,
        coverage_tool):
    """Define a toolchain implementation for a python-build-standalone repo.

    It expected this macro is called in the top-level package of an extracted
    python-build-standalone repository. See
    python/private/python_repositories.bzl for how it is invoked.

    Args:
        name: {type}`str` name used for tools to identify the invocation.
        extra_files_glob_include: {type}`list[str]` additional glob include
            patterns for the target runtime files (the one included in
            binaries).
        extra_files_glob_exclude: {type}`list[str]` additional glob exclude
            patterns for the target runtime files.
        python_version: {type}`str` The Python version, in `major.minor.micro`
            format.
        python_bin: {type}`str` The path to the Python binary within the
            repositoroy.
        coverage_tool: {type}`str` optional target to the coverage tool to
            use.
    """
    _ = name  # @unused
    python_version_info = python_version.split(".")
    major = python_version_info[0]
    minor = python_version_info[1]
    native.filegroup(
        name = "files",
        srcs = native.glob(
            include = [
                "bin/**",
                "extensions/**",
                "include/**",
                "libs/**",
                "share/**",
            ] + extra_files_glob_include,
            # Platform-agnostic filegroup can't match on all patterns.
            allow_empty = True,
            exclude = [
                "**/* *",  # Bazel does not support spaces in file names.
                # Unused shared libraries. `python` executable and the `:libpython` target
                # depend on `libpython{python_version}.so.1.0`.
                "lib/libpython{}.{}.so".format(major, minor),
                # static libraries
                "lib/**/*.a",
                # tests for the standard libraries.
                "lib/python{}.{}/**/test/**".format(major, minor),
                "lib/python{}.{}/**/tests/**".format(major, minor),
                "**/__pycache__/*.pyc.*",  # During pyc creation, temp files named *.pyc.NNN are created
            ] + extra_files_glob_exclude,
        ),
    )
    cc_import(
        name = "interface",
        interface_library = "libs/python{}{}.lib".format(major, minor),
        system_provided = True,
    )

    native.filegroup(
        name = "includes",
        srcs = native.glob(["include/**/*.h"]),
    )
    cc_library(
        name = "python_headers",
        deps = select({
            "@bazel_tools//src/conditions:windows": [":interface"],
            "//conditions:default": None,
        }),
        hdrs = [":includes"],
        includes = [
            "include",
            "include/python{}.{}".format(major, minor),
            "include/python{}.{}m".format(major, minor),
        ],
    )
    cc_library(
        name = "libpython",
        hdrs = [":includes"],
        srcs = select({
            "@platforms//os:linux": [
                "lib/libpython{}.{}.so".format(major, minor),
                "lib/libpython{}.{}.so.1.0".format(major, minor),
            ],
            "@platforms//os:macos": ["lib/libpython{}.{}.dylib".format(major, minor)],
            "@platforms//os:windows": ["python3.dll", "libs/python{}{}.lib".format(major, minor)],
        }),
    )

    native.exports_files(["python", python_bin])

    # Used to only download coverage toolchain when the coverage is collected by
    # bazel.
    native.config_setting(
        name = "coverage_enabled",
        values = {"collect_code_coverage": "true"},
        visibility = ["//visibility:private"],
    )
    py_runtime_kwargs = {}
    if coverage_tool:
        # Earlier versions of Bazel don't support this attribute.
        py_runtime_kwargs["coverage_tool"] = coverage_tool

    py_runtime(
        name = "py3_runtime",
        files = [":files"],
        interpreter = python_bin,
        interpreter_version_info = {
            "major": str(major),
            "micro": str(python_version_info[2]),
            "minor": str(minor),
        },
        python_version = "PY3",
        implementation_name = "cpython",
        pyc_tag = "cpython-{}{}".format(major, minor),
        **py_runtime_kwargs
    )

    py_runtime_pair(
        name = "python_runtimes",
        py2_runtime = None,
        py3_runtime = ":py3_runtime",
    )

    py_cc_toolchain(
        name = "py_cc_toolchain",
        headers = ":python_headers",
        libs = ":libpython",
        python_version = python_version,
    )

    py_exec_tools_toolchain(
        name = "py_exec_tools_toolchain",
        precompiler = "@rules_python//tools/precompiler:precompiler",
    )
