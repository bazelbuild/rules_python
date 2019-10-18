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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Load our production dependencies using the federation, except that instead of
# calling rules_python() (which would define the @rules_python repo), we just
# call rules_python_deps().

http_archive(
    name = "bazel_federation",
    url = "https://github.com/bazelbuild/bazel-federation/releases/download/0.0.1/bazel_federation-0.0.1.tar.gz",
    sha256 = "506dfbfd74ade486ac077113f48d16835fdf6e343e1d4741552b450cfc2efb53",
)

load("@bazel_federation//:repositories.bzl", "rules_python_deps")
rules_python_deps()

load("@bazel_federation//setup:rules_python.bzl",  "rules_python_setup")
rules_python_setup(use_pip=True)

# Everything below this line is used only for developing rules_python. Users
# should not copy it to their WORKSPACE.

load("//:internal_deps.bzl", "rules_python_internal_deps")
rules_python_internal_deps()

load("//:internal_setup.bzl", "rules_python_internal_setup")
rules_python_internal_setup()
