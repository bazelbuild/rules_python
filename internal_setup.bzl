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

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@cgrindel_bazel_starlib//:deps.bzl", "bazel_starlib_dependencies")
load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
load("@rules_bazel_integration_test//bazel_integration_test:deps.bzl", "bazel_integration_test_rules_dependencies")
load("@rules_bazel_integration_test//bazel_integration_test:repo_defs.bzl", "bazel_binaries")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:internal_config_repo.bzl", "internal_config_repo")  # buildifier: disable=bzl-visibility
load("//:version.bzl", "SUPPORTED_BAZEL_VERSIONS")

def rules_python_internal_setup():
    """Setup for rules_python tests and tools."""

    internal_config_repo(name = "rules_python_internal")

    # Because we don't use the pip_install rule, we have to call this to fetch its deps
    pip_install_dependencies()

    bazel_skylib_workspace()

    rules_proto_dependencies()
    rules_proto_toolchains()

    protobuf_deps()

    bazel_integration_test_rules_dependencies()
    bazel_starlib_dependencies()
    bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)
