# Copyright 2019 The Bazel Authors. All rights reserved.
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
package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("//python:defs.bzl", "py_library")
load("//experimental/python:pytest.bzl", "pytest_test")
load("@examples_pytest//:requirements.bzl", "requirement")

py_library(
    name = "conftest",
    srcs = ["conftest.py"],
)

pytest_test(
    name = "all_tests",
    test_files = glob(["*_test.py"]),
    deps = [
        ":conftest",
        requirement("pytest"),
        # These should be pulled in by requirement("pytest"), but it's currently broken
        # See #110 and #90
        requirement("attrs"),
        requirement("atomicwrites"),
        requirement("importlib_metadata"),
        requirement("more_itertools"),
        requirement("pluggy"),
        requirement("py"),
        requirement("zipp"),
    ],
)
