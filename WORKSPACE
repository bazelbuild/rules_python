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

workspace(name = "rules_python")

# Everything below this line is used only for developing rules_python. Users
# should not copy it to their WORKSPACE.

load("//:internal_deps.bzl", "rules_python_internal_deps")

rules_python_internal_deps()

load("//:internal_setup.bzl", "rules_python_internal_setup")

rules_python_internal_setup()

load("//python:repositories.bzl", "python_register_multi_toolchains")
load("//python:versions.bzl", "MINOR_MAPPING")

python_register_multi_toolchains(
    name = "python",
    default_version = MINOR_MAPPING.values()[-1],
    python_versions = MINOR_MAPPING.values(),
)

load("//gazelle:deps.bzl", "gazelle_deps")

# gazelle:repository_macro gazelle/deps.bzl%gazelle_deps
gazelle_deps()

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Used for Bazel CI
http_archive(
    name = "bazelci_rules",
    sha256 = "eca21884e6f66a88c358e580fd67a6b148d30ab57b1680f62a96c00f9bc6a07e",
    strip_prefix = "bazelci_rules-1.0.0",
    url = "https://github.com/bazelbuild/continuous-integration/releases/download/rules-1.0.0/bazelci_rules-1.0.0.tar.gz",
)

load("@bazelci_rules//:rbe_repo.bzl", "rbe_preconfig")

# Creates a default toolchain config for RBE.
# Use this as is if you are using the rbe_ubuntu16_04 container,
# otherwise refer to RBE docs.
rbe_preconfig(
    name = "buildkite_config",
    toolchain = "ubuntu1804-bazel-java11",
)
