# Copyright 2018 The Bazel Authors. All rights reserved.
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

load("//experimental/python:wheel.bzl", "py_package", "py_wheel")
load("//python:defs.bzl", "py_library", "py_test")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

py_library(
    name = "main",
    srcs = ["main.py"],
    deps = [
        "//experimental/examples/wheel/lib:simple_module",
        "//experimental/examples/wheel/lib:module_with_data",
        # Example dependency which is not packaged in the wheel
        # due to "packages" filter on py_package rule.
        "//tests/load_from_macro:foo",
    ],
)

# Package just a specific py_libraries, without their dependencies
py_wheel(
    name = "minimal_with_py_library",
    # Package data. We're building "example_minimal_library-0.0.1-py3-none-any.whl"
    distribution = "example_minimal_library",
    python_tag = "py3",
    version = "0.0.1",
    deps = [
        "//experimental/examples/wheel/lib:module_with_data",
        "//experimental/examples/wheel/lib:simple_module",
    ],
)

# Use py_package to collect all transitive dependencies of a target,
# selecting just the files within a specific python package.
py_package(
    name = "example_pkg",
    # Only include these Python packages.
    packages = ["experimental.examples.wheel"],
    deps = [":main"],
)

py_wheel(
    name = "minimal_with_py_package",
    # Package data. We're building "example_minimal_package-0.0.1-py3-none-any.whl"
    distribution = "example_minimal_package",
    python_tag = "py3",
    version = "0.0.1",
    deps = [":example_pkg"],
)

# An example that uses all features provided by py_wheel.
py_wheel(
    name = "customized",
    author = "Example Author with non-ascii characters: żółw",
    author_email = "example@example.com",
    classifiers = [
        "License :: OSI Approved :: Apache Software License",
        "Intended Audience :: Developers",
    ],
    console_scripts = {
        "customized_wheel": "experimental.examples.wheel.main:main",
    },
    description_file = "README.md",
    # Package data. We're building "example_customized-0.0.1-py3-none-any.whl"
    distribution = "example_customized",
    homepage = "www.example.com",
    license = "Apache 2.0",
    python_tag = "py3",
    # Requirements embedded into the wheel metadata.
    requires = ["pytest"],
    version = "0.0.1",
    deps = [":example_pkg"],
)

# An example of how to change the wheel package root directory using 'strip_path_prefixes'.
py_wheel(
    name = "custom_package_root",
    # Package data. We're building "custom_package_root-0.0.1-py3-none-any.whl"
    distribution = "example_custom_package_root",
    python_tag = "py3",
    strip_path_prefixes = [
        "experimental",
    ],
    version = "0.0.1",
    deps = [
        ":example_pkg",
    ],
)

py_wheel(
    name = "custom_package_root_multi_prefix",
    # Package data. We're building "custom_custom_package_root_multi_prefix-0.0.1-py3-none-any.whl"
    distribution = "example_custom_package_root_multi_prefix",
    python_tag = "py3",
    strip_path_prefixes = [
        "experimental/examples/wheel/lib",
        "experimental/examples/wheel",
    ],
    version = "0.0.1",
    deps = [
        ":example_pkg",
    ],
)

py_wheel(
    name = "custom_package_root_multi_prefix_reverse_order",
    # Package data. We're building "custom_custom_package_root_multi_prefix_reverse_order-0.0.1-py3-none-any.whl"
    distribution = "example_custom_package_root_multi_prefix_reverse_order",
    python_tag = "py3",
    strip_path_prefixes = [
        "experimental/examples/wheel",
        "experimental/examples/wheel/lib",  # this is not effective, because the first prefix takes priority
    ],
    version = "0.0.1",
    deps = [
        ":example_pkg",
    ],
)

py_test(
    name = "wheel_test",
    srcs = ["wheel_test.py"],
    data = [
        ":custom_package_root",
        ":custom_package_root_multi_prefix",
        ":custom_package_root_multi_prefix_reverse_order",
        ":customized",
        ":minimal_with_py_library",
        ":minimal_with_py_package",
    ],
)
