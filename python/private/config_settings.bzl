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
load("//python:versions.bzl", "MINOR_MAPPING", "TOOL_VERSIONS")

_PYTHON_VERSION_FLAG = str(Label("//python/config_settings:python_version"))

def _ver_key(s):
    major, _, s = s.partition(".")
    minor, _, s = s.partition(".")
    micro, _, s = s.partition(".")
    return (int(major), int(minor), int(micro))

def _flag_values(*, python_versions, minor_mapping):
    """Construct a map of python_version to a list of toolchain values.

    This mapping maps the concept of a config setting to a list of compatible toolchain versions.
    For using this in the code, the VERSION_FLAG_VALUES should be used instead.

    Args:
        python_versions: {type}`list[str]` X.Y.Z` python versions.
        minor_mapping: {type}`dict[str, str]` `X.Y` to `X.Y.Z` mapping.

    Returns:
        A `map[str, list[str]]`. Each key is a python_version flag value. Each value
        is a list of the python_version flag values that should match when for the
        `key`. For example:
        ```
         "3.8" -> ["3.8", "3.8.1", "3.8.2", ..., "3.8.19"]  # All 3.8 versions
         "3.8.2" -> ["3.8.2"]  # Only 3.8.2
         "3.8.19" -> ["3.8.19", "3.8"]  # The latest version should also match 3.8 so
             as when the `3.8` toolchain is used we just use the latest `3.8` toolchain.
             this makes the `select("is_python_3.8.19")` work no matter how the user
             specifies the latest python version to use.
        ```
    """
    ret = {}

    for micro_version in sorted(python_versions, key = _ver_key):
        minor_version, _, _ = micro_version.rpartition(".")

        # This matches the raw flag value, e.g. --//python/config_settings:python_version=3.8
        # It's private because matching the concept of e.g. "3.8" value is done
        # using the `is_python_X.Y` config setting group, which is aware of the
        # minor versions that could match instead.
        ret.setdefault(minor_version, [minor_version]).append(micro_version)

        # Ensure that is_python_3.9.8 is matched if python_version is set
        # to 3.9 if minor_mapping points to 3.9.8
        default_micro_version = minor_mapping[minor_version]
        ret[micro_version] = [micro_version, minor_version] if default_micro_version == micro_version else [micro_version]

    return ret

VERSION_FLAG_VALUES = _flag_values(python_versions = TOOL_VERSIONS.keys(), minor_mapping = MINOR_MAPPING)

def is_python_config_setting(name, *, python_version, reuse_conditions = None, **kwargs):
    """Create a config setting for matching 'python_version' configuration flag.

    This function is mainly intended for internal use within the `whl_library` and `pip_parse`
    machinery.

    The matching of the 'python_version' flag depends on the value passed in
    `python_version` and here is the example for `3.8` (but the same applies
    to other python versions present in @//python:versions.bzl#TOOL_VERSIONS):
     * "3.8" -> ["3.8", "3.8.1", "3.8.2", ..., "3.8.19"]  # All 3.8 versions
     * "3.8.2" -> ["3.8.2"]  # Only 3.8.2
     * "3.8.19" -> ["3.8.19", "3.8"]  # The latest version should also match 3.8 so
         as when the `3.8` toolchain is used we just use the latest `3.8` toolchain.
         this makes the `select("is_python_3.8.19")` work no matter how the user
         specifies the latest python version to use.

    Args:
        name: name for the target that will be created to be used in select statements.
        python_version: The python_version to be passed in the `flag_values` in the
            `config_setting`. Depending on the version, the matching python version list
            can be as described above.
        reuse_conditions: A dict of version to version label for which we should
            reuse config_setting targets instead of creating them from scratch. This
            is useful when using is_python_config_setting multiple times in the
            same package with the same `major.minor` python versions.
        **kwargs: extra kwargs passed to the `config_setting`.
    """
    if python_version not in name:
        fail("The name '{}' must have the python version '{}' in it".format(name, python_version))

    if python_version not in VERSION_FLAG_VALUES:
        fail("The 'python_version' must be known to 'rules_python', choose from the values: {}".format(VERSION_FLAG_VALUES.keys()))

    python_versions = VERSION_FLAG_VALUES[python_version]
    extra_flag_values = kwargs.pop("flag_values", {})
    if _PYTHON_VERSION_FLAG in extra_flag_values:
        fail("Cannot set '{}' in the flag values".format(_PYTHON_VERSION_FLAG))

    if len(python_versions) == 1:
        native.config_setting(
            name = name,
            flag_values = {
                _PYTHON_VERSION_FLAG: python_version,
            } | extra_flag_values,
            **kwargs
        )
        return

    reuse_conditions = reuse_conditions or {}
    create_config_settings = {
        "_{}".format(name).replace(python_version, version): {_PYTHON_VERSION_FLAG: version}
        for version in python_versions
        if not reuse_conditions or version not in reuse_conditions
    }
    match_any = list(create_config_settings.keys())
    for version, condition in reuse_conditions.items():
        if len(VERSION_FLAG_VALUES[version]) == 1:
            match_any.append(condition)
            continue

        # Convert the name to an internal label that this function would create,
        # so that we are hitting the config_setting and not the config_setting_group.
        condition = Label(condition)
        if hasattr(condition, "same_package_label"):
            condition = condition.same_package_label("_" + condition.name)
        else:
            condition = condition.relative("_" + condition.name)

        match_any.append(condition)

    for name_, flag_values_ in create_config_settings.items():
        native.config_setting(
            name = name_,
            flag_values = flag_values_ | extra_flag_values,
            **kwargs
        )

    # An alias pointing to an underscore-prefixed config_setting_group
    # is used because config_setting_group creates
    # `is_{version}_N` targets, which are easily confused with the
    # `is_{minor}.{micro}` (dot) targets.
    selects.config_setting_group(
        name = "_{}_group".format(name),
        match_any = match_any,
        visibility = ["//visibility:private"],
    )
    native.alias(
        name = name,
        actual = "_{}_group".format(name),
        visibility = kwargs.get("visibility", []),
    )

def construct_config_settings(name = None):  # buildifier: disable=function-docstring
    """Create a 'python_version' config flag and construct all config settings used in rules_python.

    This mainly includes the targets that are used in the toolchain and pip hub
    repositories that only match on the 'python_version' flag values.

    Args:
        name(str): A dummy name value that is no-op for now.
    """
    _python_version_flag(
        name = "python_version",
        # TODO: The default here should somehow match the MODULE config. Until
        # then, use the empty string to indicate an unknown version. This
        # also prevents version-unaware targets from inadvertently matching
        # a select condition when they shouldn't.
        build_setting_default = "",
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "is_python_version_unset",
        flag_values = {
            Label("//python/config_settings:python_version"): "",
        },
        visibility = ["//visibility:public"],
    )

    for version, matching_versions in VERSION_FLAG_VALUES.items():
        is_python_config_setting(
            name = "is_python_{}".format(version),
            python_version = version,
            reuse_conditions = {
                v: native.package_relative_label("is_python_{}".format(v))
                for v in matching_versions
                if v != version
            },
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
