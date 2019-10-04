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

###############################################################################
# To regenerate documentation, run the top-level update_docs.sh script.       #
###############################################################################

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@io_bazel_skydoc//stardoc:stardoc.bzl", "stardoc")

# We define these bzl_library targets here rather than in the //python package
# because they're only used for doc generation. This way, we avoid requiring
# our users to depend on Skylib.

# Requires Bazel 0.29 onward for public visibility of these .bzl files.
bzl_library(
    name = "bazel_python_tools",
    srcs = [
        "@bazel_tools//tools/python:srcs_version.bzl",
        "@bazel_tools//tools/python:toolchain.bzl",
        "@bazel_tools//tools/python:utils.bzl",
        "@bazel_tools//tools/python:private/defs.bzl",
    ],
)

bzl_library(
    name = "defs",
    srcs = [
        "//python:defs.bzl",
        "//python:private/reexports.bzl",
    ],
    deps = [":bazel_python_tools"],
)

stardoc(
    name = "core-docs",
    input = "//python:defs.bzl",
    out = "python.md",
    deps = [":defs"],
)

# TODO: Consider merging documentation pages for whl and pip. This would
# require re-exporting their symbols from a common .bzl; see
# https://github.com/bazelbuild/skydoc/issues/208.

stardoc(
    name = "pip-docs",
    input = "//python:pip.bzl",
    out = "pip.md",
)

stardoc(
    name = "whl-docs",
    input = "//python:whl.bzl",
    out = "whl.md",
)
