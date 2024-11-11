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

"""pkg_aliases is a macro to generate aliases for selecting the right wheel for the right target platform.

This is used in bzlmod and non-bzlmod setups."""

load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
    #"PY_LIBRARY_IMPL_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    #"WHEEL_FILE_IMPL_LABEL",
    "WHEEL_FILE_PUBLIC_LABEL",
)

def pkg_aliases(
        *,
        name,
        actual,
        native = native):
    """Create aliases for an actual package.

    Args:
        name: {type}`str` The name of the package.
        actual: {type}`dict[Label, str]` The config settings for the package
            mapping to repositories.
        native: {type}`struct` used in unit tests
    """
    _ = actual  # buildifier: @unused
    native.alias(
        name = name,
        actual = ":" + PY_LIBRARY_PUBLIC_LABEL,
    )

    target_names = {
        x: x
        for x in [
            PY_LIBRARY_PUBLIC_LABEL,
            WHEEL_FILE_PUBLIC_LABEL,
            DATA_LABEL,
            DIST_INFO_LABEL,
        ]
    }

    if type(actual) == type({}):
        fail("TODO")

    repo = actual

    for name, target_name in target_names.items():
        native.alias(
            name = name,
            actual = "@{repo}//:{target_name}".format(
                repo = repo,
                target_name = target_name,
            ),
        )
