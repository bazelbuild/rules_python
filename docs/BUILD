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

# To regenerate html docs, run:
#   ./update_docs.sh

load("@bazel_skylib//:skylark_library.bzl", "skylark_library")
load("@io_bazel_skydoc//skylark:skylark.bzl", "skylark_doc")

skylark_library(
    name = "whl",
    srcs = ["//python:whl.bzl"],
)

skylark_library(
    name = "pip",
    srcs = ["//python:pip.bzl"],
)

skylark_library(
    name = "python",
    srcs = ["//python:python.bzl"],
)

skylark_doc(
    name = "docs-md",
    format = "markdown",
    overview = True,
    site_root = ".",
    deps = [
        ":pip",
        ":python",
        ":whl",
    ],
)

skylark_doc(
    name = "docs-html",
    format = "html",
    overview = True,
    site_root = ".",
    deps = [
        ":pip",
        ":python",
        ":whl",
    ],
)
