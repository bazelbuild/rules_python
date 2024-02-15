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
load("//python/private:config_settings.bzl", _VERSION_FLAG_VALUES = "VERSION_FLAG_VALUES", _is_python_config_setting = "is_python_config_setting")

VERSION_FLAG_VALUES = _VERSION_FLAG_VALUES
is_python_config_setting = _is_python_config_setting

def construct_config_settings(name = None):  # buildifier: disable=function-docstring
    string_flag(
        name = "python_version",
        # TODO: The default here should somehow match the MODULE config. Until
        # then, use the empty string to indicate an unknown version. This
        # also prevents version-unaware targets from inadvertently matching
        # a select condition when they shouldn't.
        build_setting_default = "",
        values = [""] + VERSION_FLAG_VALUES.keys(),
        visibility = ["//visibility:public"],
    )

    for version, matching_versions in VERSION_FLAG_VALUES.items():
        match_any = None
        if len(matching_versions) > 1:
            match_any = [
                # Use the internal labels created by this macro in order to handle matching
                # 3.8 config value if using the 3.8 version from MINOR_MAPPING with generating
                # fewer targets overall.
                ("_is_python_{}" if len(VERSION_FLAG_VALUES[v]) > 1 else "is_python_{}").format(v)
                for v in matching_versions
            ]

        is_python_config_setting(
            name = "is_python_{}".format(version),
            python_version = version,
            match_any = match_any,
            visibility = ["//visibility:public"],
        )
