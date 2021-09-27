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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

_DOCS = {
    "packaging": "//docs:packaging-docs",
    "pip": "//docs:pip-docs",
    "python": "//docs:core-docs",
    "whl": "//docs:whl-docs",
}

# We define these bzl_library targets here rather than in the //python package
# because they're only used for doc generation. This way, we avoid requiring
# our users to depend on Skylib.

# Requires Bazel 0.29 onward for public visibility of these .bzl files.
bzl_library(
    name = "bazel_python_tools",
    srcs = [
        "@bazel_tools//tools/python:private/defs.bzl",
        "@bazel_tools//tools/python:srcs_version.bzl",
        "@bazel_tools//tools/python:toolchain.bzl",
        "@bazel_tools//tools/python:utils.bzl",
    ],
)

bzl_library(
    name = "bazel_repo_tools",
    srcs = [
        "@bazel_tools//tools:bzl_srcs",
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

bzl_library(
    name = "pip_install_bzl",
    srcs = [
        "//python/pip_install:pip_repository.bzl",
        "//python/pip_install:repositories.bzl",
        "//python/pip_install:requirements.bzl",
    ],
    deps = [
        ":defs",
    ],
)

stardoc(
    name = "core-docs",
    out = "python.md_",
    input = "//python:defs.bzl",
    deps = [":defs"],
)

# TODO: Consider merging documentation pages for whl and pip. This would
# require re-exporting their symbols from a common .bzl; see
# https://github.com/bazelbuild/skydoc/issues/208.

stardoc(
    name = "pip-docs",
    out = "pip.md_",
    input = "//python:pip.bzl",
    deps = [
        ":bazel_repo_tools",
        ":pip_install_bzl",
        "//third_party/github.com/bazelbuild/bazel-skylib/lib:versions",
    ],
)

stardoc(
    name = "whl-docs",
    out = "whl.md_",
    input = "//python:whl.bzl",
)

stardoc(
    name = "packaging-docs",
    out = "packaging.md_",
    input = "//python:packaging.bzl",
)

[
    diff_test(
        name = "check_" + k,
        failure_message = "Please run:   bazel run //docs:update",
        file1 = k + ".md",
        file2 = k + ".md_",
    )
    for k in _DOCS.keys()
]

write_file(
    name = "gen_update",
    out = "update.sh",
    content = [
        "#!/usr/bin/env bash",
        "cd $BUILD_WORKSPACE_DIRECTORY",
    ] + [
        "cp -fv bazel-bin/docs/{0}.md_ docs/{0}.md".format(k)
        for k in _DOCS.keys()
    ],
)

sh_binary(
    name = "update",
    srcs = ["update.sh"],
    data = _DOCS.values(),
)
