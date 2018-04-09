# Copyright 2017 The Bazel Authors. All rights reserved.
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

load("//python:python.bzl", "py_binary", "py_library", "py_test")
load("@piptool_deps//:requirements.bzl", "requirement")

py_library(
    name = "whl",
    srcs = ["whl.py"],
    deps = [
        requirement("setuptools"),
    ],
)

py_test(
    name = "whl_test",
    srcs = ["whl_test.py"],
    data = [
        "@futures_3_1_1_whl//file",
        "@futures_2_2_0_whl//file",
        "@google_cloud_language_whl//file",
        "@grpc_whl//file",
        "@mock_whl//file",
        "@wheel_0_31_1_whl//file",
    ],
    deps = [
        ":whl",
        requirement("mock"),
    ],
)

load("@subpar//:subpar.bzl", "par_binary")

par_binary(
    name = "piptool",
    srcs = ["piptool.py"],
    deps = [
        ":whl",
        requirement("pip"),
        requirement("wheel"),
    ],
)

par_binary(
    name = "whltool",
    srcs = ["whl.py"],
    main = "whl.py",
    deps = [
        ":whl",
    ],
)
