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

"""Macro to generate all of the targets present in a {obj}`whl_library`."""

load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
)

def whl_library_targets(
        name,
        *,
        filegroups = {
            DIST_INFO_LABEL: ["site-packages/*.dist-info/**"],
            DATA_LABEL: ["data/**"],
        },
        native = native):
    """Create all of the whl_library targets.

    Args:
        name: {type}`str` Currently unused.
        filegroups: {type}`dict[str, list[str]]` A dictionary of the target
            names and the glob matches.
        native: {type}`native` The native struct for overriding in tests.
    """
    _ = name  # buildifier: @unused
    for name, glob in filegroups.items():
        native.filegroup(
            name = name,
            srcs = native.glob(glob, allow_empty = True),
        )
