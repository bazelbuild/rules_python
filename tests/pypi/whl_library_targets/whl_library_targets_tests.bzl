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

""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private/pypi:whl_library_targets.bzl", "whl_library_targets")  # buildifier: disable=bzl-visibility

_tests = []

def _test_filegroups(env):
    calls = []

    def glob(match, *, allow_empty):
        env.expect.that_bool(allow_empty).equals(True)
        return match

    whl_library_targets(
        name = "dummy",
        native = struct(
            filegroup = lambda **kwargs: calls.append(kwargs),
            glob = glob,
        ),
    )

    env.expect.that_collection(calls).contains_exactly([
        {
            "name": "dist_info",
            "srcs": ["site-packages/*.dist-info/**"],
        },
        {
            "name": "data",
            "srcs": ["data/**"],
        },
    ])

_tests.append(_test_filegroups)

def _test_platforms(env):
    calls = []

    whl_library_targets(
        name = "dummy",
        dependencies_by_platform = {
            "@//python/config_settings:is_python_3.9": ["py39_dep"],
            "@platforms//cpu:aarch64": ["arm_dep"],
            "@platforms//os:windows": ["win_dep"],
            "cp310_linux_ppc": ["py310_linux_ppc_dep"],
            "cp39_anyos_aarch64": ["py39_arm_dep"],
            "cp39_linux_anyarch": ["py39_linux_dep"],
            "linux_x86_64": ["linux_intel_dep"],
        },
        filegroups = {},
        native = struct(
            config_setting = lambda **kwargs: calls.append(kwargs),
        ),
    )

    env.expect.that_collection(calls).contains_exactly([
        dict(
            name = "is_python_3.10_linux_ppc",
            flag_values = {
                "@rules_python//python/config_settings:python_version_major_minor": "3.10",
            },
            constraint_values = [
                "@platforms//cpu:ppc",
                "@platforms//os:linux",
            ],
            visibility = ["//visibility:private"],
        ),
        dict(
            name = "is_python_3.9_anyos_aarch64",
            flag_values = {
                "@rules_python//python/config_settings:python_version_major_minor": "3.9",
            },
            constraint_values = ["@platforms//cpu:aarch64"],
            visibility = ["//visibility:private"],
        ),
        dict(
            name = "is_python_3.9_linux_anyarch",
            flag_values = {
                "@rules_python//python/config_settings:python_version_major_minor": "3.9",
            },
            constraint_values = ["@platforms//os:linux"],
            visibility = ["//visibility:private"],
        ),
        dict(
            name = "is_linux_x86_64",
            flag_values = None,
            constraint_values = [
                "@platforms//cpu:x86_64",
                "@platforms//os:linux",
            ],
            visibility = ["//visibility:private"],
        ),
    ])

_tests.append(_test_platforms)

def _test_copy(env):
    calls = []

    whl_library_targets(
        name = "dummy",
        dependencies_by_platform = {},
        filegroups = {},
        copy_files = {"file_src": "file_dest"},
        copy_executables = {"exec_src": "exec_dest"},
        copy_file_rule = lambda **kwargs: calls.append(kwargs),
    )

    env.expect.that_collection(calls).contains_exactly([
        {
            "is_executable": False,
            "name": "file_dest.copy",
            "out": "file_dest",
            "src": "file_src",
        },
        {
            "is_executable": True,
            "name": "exec_dest.copy",
            "out": "exec_dest",
            "src": "exec_src",
        },
    ])

_tests.append(_test_copy)

def _test_entrypoints(env):
    calls = []

    whl_library_targets(
        name = "dummy",
        dependencies_by_platform = {},
        filegroups = {},
        entry_points = {
            "fizz": "buzz.py",
        },
        py_binary_rule = lambda **kwargs: calls.append(kwargs),
    )

    env.expect.that_collection(calls).contains_exactly([
        dict(
            name = "rules_python_wheel_entry_point_fizz",
            srcs = ["buzz.py"],
            imports = ["."],
            deps = [":pkg"],
        ),
    ])

_tests.append(_test_entrypoints)

def whl_library_targets_test_suite(name):
    """create the test suite.

    args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
