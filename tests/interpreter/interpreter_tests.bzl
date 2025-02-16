# Copyright 2025 The Bazel Authors. All rights reserved.
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

load("//tests/support:sh_py_run_test.bzl", "py_reconfig_test")

PYTHON_VERSIONS_TO_TEST = (
    "3.10",
    "3.11",
    "3.12",
)

def py_reconfig_interpreter_tests(name, python_versions, expected_interpreter_version=None, env={}, **kwargs):
    for python_version in python_versions:
        py_reconfig_test(
            name = "{}_{}".format(name, python_version),
            env = env | {
                "EXPECTED_INTERPRETER_VERSION": expected_interpreter_version or python_version,
                "EXPECTED_SELF_VERSION": python_version,
            },
            python_version = python_version,
            **kwargs
        )

    native.test_suite(
        name = name,
        tests = [":{}_{}".format(name, python_version) for python_version in python_versions],
    )
