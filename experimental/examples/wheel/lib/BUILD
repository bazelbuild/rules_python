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
package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("//python:defs.bzl", "py_library")

py_library(
    name = "simple_module",
    srcs = ["simple_module.py"],
)

py_library(
    name = "module_with_data",
    srcs = ["module_with_data.py"],
    data = [":data.txt"],
)

genrule(
    name = "make_data",
    outs = ["data.txt"],
    cmd = "echo foo bar baz > $@",
)
