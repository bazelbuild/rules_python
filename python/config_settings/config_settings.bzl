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

def construct_config_settings(name, python_versions):
    """Constructs a set of configs for all Python versions.

    Args:
        name: str, unused; only specified to satisfy buildifier lint checks
            and allow programatic modification of the target.
        python_versions: list of all (x.y.z) Python versions supported by rules_python.
    """

    # Maps e.g. "3.8" -> ["3.8.1", "3.8.2", etc]
    minor_to_micro_versions = {}
    allowed_flag_values = []
    for micro_version in python_versions:
        minor, _, _ = micro_version.rpartition(".")
        minor_to_micro_versions.setdefault(minor, []).append(micro_version)
        allowed_flag_values.append(micro_version)

    string_flag(
        name = "python_version",
        # TODO: The default here should somehow match the MODULE config
        build_setting_default = python_versions[0],
        values = sorted(allowed_flag_values),
        visibility = ["//visibility:public"],
    )

    for minor_version, micro_versions in minor_to_micro_versions.items():
        # This matches the raw flag value, e.g. --///python/config_settings:python_version=3.8
        # It's private because matching the concept of e.g. "3.8" value is done
        # using the `is_python_X.Y` config setting group, which is aware of the
        # minor versions that could match instead.
        equals_minor_version_name = "_python_version_flag_equals_" + minor_version
        native.config_setting(
            name = equals_minor_version_name,
            flag_values = {":python_version": minor_version},
        )

        matches_minor_version_names = [equals_minor_version_name]

        for micro_version in micro_versions:
            is_micro_version_name = "is_python_" + micro_version
            native.config_setting(
                name = is_micro_version_name,
                flag_values = {":python_version": micro_version},
                visibility = ["//visibility:public"],
            )
            matches_minor_version_names.append(is_micro_version_name)

        selects.config_setting_group(
            name = "is_python_" + minor_version,
            match_any = matches_minor_version_names,
            visibility = ["//visibility:public"],
        )
