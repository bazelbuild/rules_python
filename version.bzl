# Copyright 2019 The Bazel Authors. All rights reserved.
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
"""The version of rules_python."""

version = "0.0.2"

# Currently used Bazel version. This version is what the rules here are tested
# against.
# This version should be updated together with the version of the Bazel
# in .bazelversion.
# TODO(alexeagle): assert this is the case in a test
BAZEL_VERSION = "3.3.1"

# Versions of Bazel which users should be able to use.
# Ensures we don't break backwards-compatibility,
# accidentally forcing users to update their LTS-supported bazel.
# These are the versions used when testing nested workspaces with
# bazel_integration_test.
SUPPORTED_BAZEL_VERSIONS = [
    # TODO: add LTS versions of bazel like 1.0.0, 2.0.0
    BAZEL_VERSION,
]
