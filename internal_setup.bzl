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

"""Setup for rules_python tests and tools."""

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@build_bazel_integration_testing//tools:repositories.bzl", "bazel_binaries")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("//:version.bzl", "SUPPORTED_BAZEL_VERSIONS")
load("//gazelle:deps.bzl", _go_repositories = "gazelle_deps")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")

def rules_python_internal_setup():
    """Setup for rules_python tests and tools."""

    # Because we don't use the pip_install rule, we have to call this to fetch its deps
    pip_install_dependencies()

    # Depend on the Bazel binaries for running bazel-in-bazel tests
    bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)

    bazel_skylib_workspace()

    # gazelle:repository_macro gazelle/deps.bzl%gazelle_deps
    _go_repositories()

    go_rules_dependencies()

    go_register_toolchains(version = "1.18")

    gazelle_dependencies()
