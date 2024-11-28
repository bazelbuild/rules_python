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

"""This module is used to construct the config settings in the BUILD file in this same package.
"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(":semver.bzl", "semver")

_PYTHON_VERSION_FLAG = Label("//python/config_settings:python_version")
_PYTHON_VERSION_MAJOR_MINOR_FLAG = Label("//python/config_settings:python_version_major_minor")

def construct_config_settings(*, name, default_version, versions, minor_mapping):  # buildifier: disable=function-docstring
    """Create a 'python_version' config flag and construct all config settings used in rules_python.

    This mainly includes the targets that are used in the toolchain and pip hub
    repositories that only match on the 'python_version' flag values.

    Args:
        name: {type}`str` A dummy name value that is no-op for now.
        default_version: {type}`str` the default value for the `python_version` flag.
        versions: {type}`list[str]` A list of versions to build constraint settings for.
        minor_mapping: {type}`dict[str, str]` A mapping from `X.Y` to `X.Y.Z` python versions.
    """
    _ = name  # @unused
    _python_version_flag(
        name = _PYTHON_VERSION_FLAG.name,
        build_setting_default = default_version,
        visibility = ["//visibility:public"],
    )

    _python_version_major_minor_flag(
        name = _PYTHON_VERSION_MAJOR_MINOR_FLAG.name,
        build_setting_default = "",
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "is_python_version_unset",
        flag_values = {_PYTHON_VERSION_FLAG: ""},
        visibility = ["//visibility:public"],
    )

    _reverse_minor_mapping = {full: minor for minor, full in minor_mapping.items()}
    for version in versions:
        minor_version = _reverse_minor_mapping.get(version)
        if not minor_version:
            native.config_setting(
                name = "is_python_{}".format(version),
                flag_values = {":python_version": version},
                visibility = ["//visibility:public"],
            )
            continue

        # Also need to match the minor version when using
        name = "is_python_{}".format(version)
        native.config_setting(
            name = "_" + name,
            flag_values = {":python_version": version},
            visibility = ["//visibility:public"],
        )

        # An alias pointing to an underscore-prefixed config_setting_group
        # is used because config_setting_group creates
        # `is_{version}_N` targets, which are easily confused with the
        # `is_{minor}.{micro}` (dot) targets.
        selects.config_setting_group(
            name = "_{}_group".format(name),
            match_any = [
                ":_is_python_{}".format(version),
                ":is_python_{}".format(minor_version),
            ],
            visibility = ["//visibility:private"],
        )
        native.alias(
            name = name,
            actual = "_{}_group".format(name),
            visibility = ["//visibility:public"],
        )

    # This matches the raw flag value, e.g. --//python/config_settings:python_version=3.8
    # It's private because matching the concept of e.g. "3.8" value is done
    # using the `is_python_X.Y` config setting group, which is aware of the
    # minor versions that could match instead.
    for minor in minor_mapping.keys():
        native.config_setting(
            name = "is_python_{}".format(minor),
            flag_values = {_PYTHON_VERSION_MAJOR_MINOR_FLAG: minor},
            visibility = ["//visibility:public"],
        )

def _python_version_flag_impl(ctx):
    value = ctx.build_setting_value
    return [
        # BuildSettingInfo is the original provider returned, so continue to
        # return it for compatibility
        BuildSettingInfo(value = value),
        # FeatureFlagInfo is returned so that config_setting respects the value
        # as returned by this rule instead of as originally seen on the command
        # line.
        # It is also for Google compatibility, which expects the FeatureFlagInfo
        # provider.
        config_common.FeatureFlagInfo(value = value),
    ]

_python_version_flag = rule(
    implementation = _python_version_flag_impl,
    build_setting = config.string(flag = True),
    attrs = {},
)

def _python_version_major_minor_flag_impl(ctx):
    input = ctx.attr._python_version_flag[config_common.FeatureFlagInfo].value
    if input:
        version = semver(input)
        value = "{}.{}".format(version.major, version.minor)
    else:
        value = ""

    return [config_common.FeatureFlagInfo(value = value)]

_python_version_major_minor_flag = rule(
    implementation = _python_version_major_minor_flag_impl,
    build_setting = config.string(flag = False),
    attrs = {
        "_python_version_flag": attr.label(
            default = _PYTHON_VERSION_FLAG,
        ),
    },
)
