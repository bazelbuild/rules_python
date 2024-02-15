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
        python_versions: A list of all versions.

    Returns:
        A map with config settings as keys and values as extra flag values to be included in
        the config_setting_group if they should be also matched, which is used for generating
        correct entries for matching the latest 3.8 version, etc.
    """

    # Maps e.g.
    #   "3.8" -> ["3.8.1", "3.8.2", ..., "3.8.19"]
    #   "3.8.2" -> []  # no extra versions
    #   "3.8.19" -> ["3.8"] # The last version should also match 3.8
    ret = {}

    for micro_version in sorted(python_versions, key = _ver_key):
        minor_version, _, _ = micro_version.rpartition(".")

        # This matches the raw flag value, e.g. --//python/config_settings:python_version=3.8
        # It's private because matching the concept of e.g. "3.8" value is done
        # using the `is_python_X.Y` config setting group, which is aware of the
        # minor versions that could match instead.
        ret.setdefault(minor_version, []).append(micro_version)

        # Ensure that is_python_3.9.8 is matched if python_version is set
        # to 3.9 if MINOR_MAPPING points to 3.9.8
        default_micro_version = MINOR_MAPPING[minor_version]
        ret[micro_version] = [minor_version] if default_micro_version == micro_version else []

    return ret

VERSION_FLAG_VALUES = _flag_values(TOOL_VERSIONS.keys())

def is_python_config_setting(name, *, python_version = None, match_extra = None, **kwargs):
    """Create a config setting for matching 'python_version' configuration flag.

    This function is mainly intended for internal use within the `whl_library` and `pip_parse`
    machinery.

    Args:
        name: name for the target that will be created to be used in select statements.
        python_version: The python_version to be passed in the `flag_values` in the `config_setting`.
        match_extra: The labels that should be used for matching the extra versions instead of creating
            them on the fly. This will be passed to `config_setting_group.match_extra`.
        **kwargs: extra kwargs passed to the `config_setting`
    """
    visibility = kwargs.pop("visibility", [])

    flag_values = {
        _PYTHON_VERSION_FLAG: python_version,
    }
    if python_version not in name:
        fail("The name must have the python version in it")

    match_extra = match_extra or {
        "_{}".format(name).replace(python_version, x): {_PYTHON_VERSION_FLAG: x}
        for x in VERSION_FLAG_VALUES[python_version]
    }
    if not match_extra:
        native.config_setting(
            name = name,
            flag_values = flag_values,
            visibility = visibility,
            **kwargs
        )
        return

    create_config_settings = {"_" + name: flag_values}
    match_any = ["_" + name]
    if type(match_extra) == type([]):
        match_any.extend(match_extra)
    elif type(match_extra) == type({}):
        match_any.extend(match_extra.keys())
        create_config_settings.update(match_extra)
    else:
        fail("unsupported match_extra type, can be either a list or a dict of dicts")

    # Create all of the necessary config setting values for the config_setting_group
    for name_, flag_values_ in create_config_settings.items():
        native.config_setting(
            name = name_,
            flag_values = flag_values_,
            # We need to pass the visibility here because of how `config_setting_group` is
            # implemented, it is using the internal aliases here, hence the need for making
            # them with the same visibility as the `alias` itself.
            visibility = visibility,
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
        visibility = visibility,
    )
