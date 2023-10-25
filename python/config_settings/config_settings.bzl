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

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

# buildifier: disable=unnamed-macro
def construct_config_settings(minor_mapping, python_versions):
    """Constructs a set of configs for all Python versions.

    Args:
        minor_mapping: mapping from minor (x.y) versions to the corresponding full (x.y.z) versions.
        python_versions: list of full (x.y.z) Python versions supported by rules_python.
    """

    minor_versions = list(minor_mapping.keys())
    allowed_flag_values = python_versions + minor_versions

    string_flag(
        name = "python_version",
        build_setting_default = python_versions[0],
        values = allowed_flag_values,
        visibility = ["//visibility:public"],
    )

    for flag_value in allowed_flag_values:
        flag_value_constraint_setting = "python_version_flag_equals_" + flag_value
        native.config_setting(
            name = flag_value_constraint_setting,
            flag_values = {":python_version": flag_value},
            visibility = ["//visibility:public"],
        )

    flag_values_that_enable_version = {
        full_version: [full_version]
        for full_version in python_versions
    }

    for minor_version, full_version in minor_mapping.items():
        flag_values_that_enable_version[full_version].append(minor_version)

    for full_version, flag_values in flag_values_that_enable_version.items():
        python_version_constraint_setting = "is_python_" + full_version
        flag_value_constraints = [
            ":python_version_flag_equals_" + flag_value
            for flag_value in flag_values
        ]
        selects.config_setting_group(
            name = python_version_constraint_setting,
            match_any = flag_value_constraints,
            visibility = ["//visibility:public"],
        )
