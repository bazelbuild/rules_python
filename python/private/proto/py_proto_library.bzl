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

"""The implementation of the `py_proto_library` rule and its aspect."""

load("@com_google_protobuf//bazel:py_proto_library.bzl", _py_proto_library = "py_proto_library")
load("//python/private:deprecation.bzl", "with_deprecation")
load("//python/private:text_utils.bzl", "render")

def py_proto_library(**kwargs):
    return _py_proto_library(
        **with_deprecation.symbol(
            kwargs,
            symbol_name = "py_proto_library",
            new_load = "@com_google_protobuf//bazel:py_proto_library.bzl",
            old_load = "@rules_python//python:proto.bzl",
            snippet = render.call(name, **{k: repr(v) for k, v in kwargs.items()}),
        )
    )
