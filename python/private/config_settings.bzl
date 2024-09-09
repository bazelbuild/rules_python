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
load(":python_version_flag.bzl", "python_version_flag")

_PYTHON_VERSION_FLAG = str(Label("//python/config_settings:python_version"))

def is_python_config_setting(name, *, python_version, reuse_conditions = None, version_flag_values = None, **kwargs):
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
        version_flag_values: A dict for using the version flag values.
        **kwargs: extra kwargs passed to the `config_setting`.
    """
    if python_version not in name:
        fail("The name '{}' must have the python version '{}' in it".format(name, python_version))

    if python_version not in version_flag_values:
        fail("The 'python_version' must be known to 'rules_python', got '{}', please choose from the values: {}".format(
            python_version,
            version_flag_values.keys(),
        ))

    python_versions = version_flag_values[python_version]
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
        if len(version_flag_values[version]) == 1:
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

def construct_config_settings(name = None, version_flag_values = None):  # buildifier: disable=function-docstring
    """Create a 'python_version' config flag and construct all config settings used in rules_python.

    This mainly includes the targets that are used in the toolchain and pip hub
    repositories that only match on the 'python_version' flag values.

    Args:
        name: {type}`str` A dummy name value that is no-op for now.
        version_flag_values: {type}`dict[str, str]` the version flag values
    """
    if not version_flag_values:
        native.alias(
            name = "python_version",
            actual = "@pythons_hub//:python_version",
            visibility = ["//visibility:public"],
        )
        return

    python_version_flag(
        name = "python_version",
        build_setting_default = "",
        values = [""] + version_flag_values.keys(),
        visibility = ["//visibility:public"],
    )

    for version, matching_versions in version_flag_values.items():
        is_python_config_setting(
            name = "is_python_{}".format(version),
            python_version = version,
            reuse_conditions = {
                v: native.package_relative_label("is_python_{}".format(v))
                for v in matching_versions
                if v != version
            },
            version_flag_values = version_flag_values,
            visibility = ["//visibility:public"],
        )

    native.config_setting(
        name = "is_python_version_unset",
        flag_values = {
            Label("//python/config_settings:python_version"): "",
        },
        visibility = ["//visibility:public"],
    )
