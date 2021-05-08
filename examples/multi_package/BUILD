# Copyright 2021 The Bazel Authors. All rights reserved.
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

load("//python:packaging.bzl", "py_wheel", "py_package")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

py_package(
    name = "multi_package_example_pkg",
    packages = [
        "examples.multi_package.bar",
        "examples.multi_package.foo",
    ],
    deps = [
        "//examples/multi_package/bar",
        "//examples/multi_package/foo",
    ],
)

py_wheel(
    name = "multi_package_example",
    # Package data. We're building "example_multi_package-0.0.1-py3-none-any.whl".
    distribution = "example_multi_package",
    python_tag = "py3",
    strip_path_prefixes = [
        "examples/multi_package",
    ],
    version = "0.0.1",
    deps = [":multi_package_example_pkg"],
    packages = [
        "bar",
        "foo",
    ],
)
