# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""This file contains macros to be called during WORKSPACE evaluation."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//python:versions.bzl", "MINOR_MAPPING", "TOOL_VERSIONS")
load("//python/private/pypi:deps.bzl", "pypi_deps")
load(":internal_config_repo.bzl", "internal_config_repo")
load(":pythons_hub.bzl", "hub_repo")

def http_archive(**kwargs):
    maybe(_http_archive, **kwargs)

def py_repositories():
    """Runtime dependencies that users must install.

    This function should be loaded and called in the user's `WORKSPACE`.
    With `bzlmod` enabled, this function is not needed since `MODULE.bazel` handles transitive deps.
    """
    maybe(
        internal_config_repo,
        name = "rules_python_internal",
    )
    maybe(
        hub_repo,
        name = "pythons_hub",
        minor_mapping = MINOR_MAPPING,
        default_python_version = "",
        toolchain_prefixes = [],
        toolchain_python_versions = [],
        toolchain_set_python_version_constraints = [],
        toolchain_user_repository_names = [],
        python_versions = sorted(TOOL_VERSIONS.keys()),
    )
    http_archive(
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        ],
    )
    http_archive(
        name = "rules_cc",
        sha256 = "d9bdd3ec66b6871456ec9c965809f43a0901e692d754885e89293807762d3d80",
        strip_prefix = "rules_cc-0.0.13",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.0.13/rules_cc-0.0.13.tar.gz"],
    )

    # Needed by rules_cc, triggerred by @rules_java_prebuilt in Bazel by using @rules_cc//cc:defs.bzl
    http_archive(
        name = "protobuf",
        sha256 = "ce5d00b78450a0ca400bf360ac00c0d599cc225f049d986a27e9a4e396c5a84a",
        strip_prefix = "protobuf-29.0-rc2",
        url = "https://github.com/protocolbuffers/protobuf/releases/download/v29.0-rc2/protobuf-29.0-rc2.tar.gz",
    )
    pypi_deps()
