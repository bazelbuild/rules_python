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

load("@piptool_deps//:requirements.bzl", "requirement")
load("//python:defs.bzl", "py_library")
load("//tools:subpar.bzl", "par_binary")

par_binary(
    name = "build_wheel",
    srcs = ["build_wheel.py"],
    deps = [
        "//tools/utils",
        requirement("pip"),
        requirement("setuptools"),
        requirement("wheel"),
    ],
)

par_binary(
    name = "extract_wheel",
    srcs = ["extract_wheel.py"],
    deps = [
       "//packaging:whl",
    ],
)

filegroup(
    name = "distribution",
    srcs = [
        "BUILD",
    ],
    visibility = ["//:__pkg__"],
)
