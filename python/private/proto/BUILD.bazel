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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_proto//proto:defs.bzl", "proto_lang_toolchain")

package(default_visibility = ["//visibility:private"])

licenses(["notice"])

filegroup(
    name = "distribution",
    srcs = glob(["**"]),
    visibility = ["//python/private:__pkg__"],
)

bzl_library(
    name = "py_proto_library_bzl",
    srcs = ["py_proto_library.bzl"],
    visibility = ["//python:__pkg__"],
    deps = [
        "//python:defs_bzl",
        "@rules_proto//proto:defs",
    ],
)

proto_lang_toolchain(
    name = "python_toolchain",
    command_line = "--python_out=%s",
    progress_message = "Generating Python proto_library %{label}",
    runtime = "@com_google_protobuf//:protobuf_python",
    # NOTE: This isn't *actually* public. It's an implicit dependency of py_proto_library,
    # so must be public so user usages of the rule can reference it.
    visibility = ["//visibility:public"],
)
