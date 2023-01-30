# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""This module is used to construct the config settings in the BUILD file in this same package.
"""

load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

# buildifier: disable=unnamed-macro
def construct_config_settings(python_versions):
    """Constructs a set of configs for all Python versions.

    Args:
        python_versions: The Python versions supported by rules_python.
    """
    string_flag(
        name = "python_version",
        build_setting_default = python_versions[0],
        values = python_versions,
        visibility = ["//visibility:public"],
    )

    for python_version in python_versions:
        python_version_constraint_setting = "is_python_" + python_version
        native.config_setting(
            name = python_version_constraint_setting,
            flag_values = {":python_version": python_version},
            visibility = ["//visibility:public"],
        )
