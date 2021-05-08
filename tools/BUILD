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
load("//python:defs.bzl", "py_binary")
load("@rules_python_packaging_deps//:requirements.bzl", "requirement")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

# Implementation detail of py_wheel rule.
py_binary(
    name = "wheelmaker",
    srcs = ["wheelmaker.py"],
)

# Implementation detail of py_wheel rule.
py_binary(
    name = "wheelversioner",
    srcs = ["wheelversioner.py"],
)

# Implementation detail of py_wheel_push rule.
py_binary(
    name = "wheelpusher",
    srcs = ["wheelpusher.py"],
    deps = [requirement("twine")],
)

exports_files(["push_wheel.sh.tpl"])

# These files are generated and updated by ./update_tools.sh
exports_files([
    "piptool.par",
    "whltool.par",
])

filegroup(
    name = "distribution",
    srcs = [
        "BUILD",
        "wheelmaker.py",
    ] + glob([
        "*.par",
    ]),
    visibility = ["//:__pkg__"],
)
