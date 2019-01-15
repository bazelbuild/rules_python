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
package(default_visibility=["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("//python:python.bzl", "py_library", "py_test")
load("//experimental/python:wheel.bzl", "py_wheel")

py_library(name="main",
           srcs=["main.py"],
           deps=["//experimental/examples/wheel/lib:simple_module",
                 "//experimental/examples/wheel/lib:module_with_data"])

# A barebones example of a wheel
py_wheel(
    name="minimal",
    # Pulls in main and all recursive dependencies,
    deps=[":main"],
    # Only include these Python packages.
    packages=["experimental.examples.wheel"],
    # Package data. We're building "example_minimal-0.0.1-py3-none-any.whl"
    wheel_name="example_minimal",
    version="0.0.1",
    python="py3",
)

# An example that uses all features provided by py_wheel.
py_wheel(
    name="customized",
    # Pulls in main and all recursive dependencies,
    deps=[":main"],
    # Only include these Python packages.
    packages=["experimental.examples.wheel"],
    # Package data. We're building "example_customized-0.0.1-py3-none-any.whl"
    wheel_name="example_customized",
    version="0.0.1",
    python="py3",
    author="Example Author with non-ascii characters: żółw",
    author_email="example@example.com",
    homepage="www.example.com",
    license="Apache 2.0",
    classifiers=["License :: OSI Approved :: Apache Software License",
                 "Intended Audience :: Developers"],
    description_file="README.md",
    # Requirements embedded into the wheel metadata.
    requires=["pytest"],
    console_scripts={
        'customized_wheel': 'experimental.examples.wheel.main:main'}
)

py_test(
    name="wheel_test",
    srcs=["wheel_test.py"],
    data=[":customized"])
