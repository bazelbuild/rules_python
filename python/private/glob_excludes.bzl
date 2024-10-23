# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Utilities for glob exclusions."

load("@bazel_features//:features.bzl", "bazel_features")

def _version_dependent_exclusions():
    """Returns glob exclusions that are sensitive to Bazel version.

    Returns:
        a list of glob exclusion patterns
    """
    if bazel_features.rules.all_characters_allowed_in_runfiles:
        return []
    else:
        return ["**/* *"]

glob_excludes = struct(
    version_dependent_exclusions = _version_dependent_exclusions,
)
