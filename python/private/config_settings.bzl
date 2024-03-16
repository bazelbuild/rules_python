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
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("//python:versions.bzl", "MINOR_MAPPING", "TOOL_VERSIONS")

_PYTHON_VERSION_FLAG = str(Label("//python/config_settings:python_version"))

def _ver_key(s):
    major, _, s = s.partition(".")
    minor, _, s = s.partition(".")
    micro, _, s = s.partition(".")
    return (int(major), int(minor), int(micro))

def _flag_values(python_versions):
    """Construct a map of python_version to a list of toolchain values.

    This mapping maps the concept of a config setting to a list of compatible toolchain versions.
    For using this in the code, the VERSION_FLAG_VALUES should be used instead.

    Args:
        python_versions: list of strings; all X.Y.Z python versions

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
        # to 3.9 if MINOR_MAPPING points to 3.9.8
        default_micro_version = MINOR_MAPPING[minor_version]
        ret[micro_version] = [micro_version, minor_version] if default_micro_version == micro_version else [micro_version]

    return ret

VERSION_FLAG_VALUES = _flag_values(TOOL_VERSIONS.keys())

def is_python_config_setting(name, *, python_version, match_any = None, **kwargs):
    """Create a config setting for matching 'python_version' configuration flag.

    This function is mainly intended for internal use within the `whl_library` and `pip_parse`
    machinery.

    Args:
        name: name for the target that will be created to be used in select statements.
        python_version: The python_version to be passed in the `flag_values` in the `config_setting`.
        match_any: The labels that should be used for matching the extra
            versions, which get passed to `config_setting_group.match_any`. If
            empty or None, this macro will create config settings necessary to
            match the `python_version` value.
        **kwargs: extra kwargs passed to the `config_setting`.
    """
    if python_version not in name:
        fail("The name '{}' must have the python version '{}' in it".format(name, python_version))

    if python_version not in VERSION_FLAG_VALUES:
        fail("The 'python_version' must be known to 'rules_python', choose from the values: {}".format(VERSION_FLAG_VALUES.keys()))

    flag_values = {
        _PYTHON_VERSION_FLAG: python_version,
    }

    python_versions = VERSION_FLAG_VALUES[python_version]
    if len(python_versions) == 1 and not match_any:
        native.config_setting(
            name = name,
            flag_values = flag_values,
            **kwargs
        )
        return

    if not match_any:
        create_config_settings = {
            "_{}".format(name).replace(python_version, version): {_PYTHON_VERSION_FLAG: version}
            for version in python_versions
        }
        match_any = list(create_config_settings.keys())
    else:
        setting_name = "_" + name if len(python_versions) > 1 else name
        create_config_settings = {setting_name: flag_values}
        if setting_name not in match_any:
            # Here we expect the user to supply us with a name of the label that
            # would be created by this function. This needs to be the case because
            # the VERSION_FLAG_VALUES values contain the all of the versions that
            # have to be matched.
            fail("'{}' must be present in 'match_any'".format(setting_name))

    for name_, flag_values_ in create_config_settings.items():
        native.config_setting(
            name = name_,
            flag_values = flag_values_,
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
            # NOTE @aignas 2024-03-16: if we don't have this, then we may create duplicate
            # targets. I think this should be improved, but I haven't figured out how yet
            # and I ran out of time.
            #
            # The fact that this parameter is needed here, suggests that we may need to
            # think of a better abstraction here.
            match_any = match_any,
            visibility = ["//visibility:public"],
        )
