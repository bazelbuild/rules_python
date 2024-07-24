# Copyright 2022 The Bazel Authors. All rights reserved.
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

""

load("//python:versions.bzl", "TOOL_VERSIONS")
load("//tests/support:sh_py_run_test.bzl", "py_reconfig_test")

def define_toolchain_tests(name):
    for python_version in TOOL_VERSIONS.keys():
        py_reconfig_test(
            name = "python_{}_test".format(python_version),
            srcs = ["python_toolchain_test.py"],
            main = "python_toolchain_test.py",
            python_version = python_version,
            env = {
                "EXPECT_PYTHON_VERSION": python_version,
            },
            deps = ["//python/runfiles"],
            data = ["//tests/support:current_build_settings"],
        )
