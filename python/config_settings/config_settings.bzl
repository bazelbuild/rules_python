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
load("//python:versions.bzl", "MINOR_MAPPING")

def construct_config_settings(name, python_versions):
    """Constructs a set of configs for all Python versions.

    Args:
        name: str, unused; only specified to satisfy buildifier lint checks
            and allow programatic modification of the target.
        python_versions: a dict of all (x.y.z) Python versions with supported
            platforms as a list for each version. This should be in the same
            format as in //python:versions.bzl#TOOL_VERSIONS.
    """

    # Maps e.g. "3.8" -> ["3.8.1", "3.8.2", etc]
    minor_to_micro_versions = {}
    minor_to_plats = {}
    micro_to_plats = {}

    allowed_flag_values = []
    for micro_version, plats in python_versions.items():
        minor, _, _ = micro_version.rpartition(".")
        minor_to_micro_versions.setdefault(minor, []).append(micro_version)
        allowed_flag_values.append(micro_version)

        for plat in plats:
            cpu, _, os = plat.partition("-")
            if "linux" in os:
                os = "linux"
            elif "darwin" in os:
                os = "osx"
            elif "windows" in os:
                os = "windows"
            else:
                fail("unknown os: {}".format(os))

            p = (os, cpu)

            # TODO @aignas 2024-02-03: use bazel skylib sets
            if minor not in minor_to_plats or p not in minor_to_plats[minor]:
                minor_to_plats.setdefault(minor, []).append(p)
            if micro_version not in micro_to_plats or (os, cpu) not in micro_to_plats[micro_version]:
                micro_to_plats.setdefault(micro_version, []).append(p)

    allowed_flag_values.extend(list(minor_to_micro_versions))

    string_flag(
        name = "python_version",
        # TODO: The default here should somehow match the MODULE config. Until
        # then, use the empty string to indicate an unknown version. This
        # also prevents version-unaware targets from inadvertently matching
        # a select condition when they shouldn't.
        build_setting_default = "",
        values = [""] + sorted(allowed_flag_values),
        visibility = ["//visibility:public"],
    )

    _construct_config_settings_for_os_cpu(
        minor_to_micro_versions = minor_to_micro_versions,
        minor_to_plats = minor_to_plats,
        micro_to_plats = micro_to_plats,
    )

def _constraint_values(plats):
    ret = {
        "": [],
    }
    _plats = []
    for (os, cpu) in plats:
        if (os, None) not in _plats:
            _plats.append((os, None))
        if (None, cpu) not in _plats:
            _plats.append((None, cpu))

        _plats.append((os, cpu))

    for (os, cpu) in _plats:
        constraint_values = []
        if os:
            constraint_values.append("@platforms//os:{}".format(os))
        if cpu:
            constraint_values.append("@platforms//cpu:{}".format(cpu))

        os = os or "any"
        cpu = cpu or "any"

        ret["_".join(["", os, cpu])] = constraint_values

    return ret

def _construct_config_settings_for_os_cpu(*, minor_to_micro_versions, minor_to_plats, micro_to_plats):
    """Constructs a set of configs for all Python versions.

    Args:
        minor_to_micro_versions: Maps e.g. "3.8" -> ["3.8.1", "3.8.2", etc]
        minor_to_plats: TODO
        micro_to_plats: TODO
    """
    for minor_version, micro_versions in minor_to_micro_versions.items():
        matches_minor_version_names = {}
        for name, constraint_values in _constraint_values(minor_to_plats[minor_version]).items():
            # This matches the raw flag value, e.g. --//python/config_settings:python_version=3.8
            # It's private because matching the concept of e.g. "3.8" value is done
            # using the `is_python_X.Y` config setting group, which is aware of the
            # minor versions that could match instead.
            equals_minor_version_name = "_python_version_flag_equals_" + minor_version + name
            native.config_setting(
                name = equals_minor_version_name,
                flag_values = {":python_version": minor_version},
                constraint_values = constraint_values,
            )
            matches_minor_version_names[name] = [equals_minor_version_name]

        for micro_version in micro_versions:
            for name, constraint_values in _constraint_values(micro_to_plats[micro_version]).items():
                is_micro_version_name = "is_python_" + micro_version + name
                if MINOR_MAPPING[minor_version] != micro_version:
                    native.config_setting(
                        name = is_micro_version_name,
                        flag_values = {":python_version": micro_version},
                        constraint_values = constraint_values,
                        visibility = ["//visibility:public"],
                    )
                    matches_minor_version_names[name].append(is_micro_version_name)
                    continue

                # Ensure that is_python_3.9.8 is matched if python_version is set
                # to 3.9 if MINOR_MAPPING points to 3.9.8
                equals_micro_name = "_python_version_flag_equals_" + micro_version + name
                native.config_setting(
                    name = equals_micro_name,
                    flag_values = {":python_version": micro_version},
                    constraint_values = constraint_values,
                )

                # An alias pointing to an underscore-prefixed config_setting_group
                # is used because config_setting_group creates
                # `is_{minor}_N` targets, which are easily confused with the
                # `is_{minor}.{micro}` (dot) targets.
                selects.config_setting_group(
                    name = "_" + is_micro_version_name,
                    match_any = [
                        equals_micro_name,
                        matches_minor_version_names[name][0],
                    ],
                )
                native.alias(
                    name = is_micro_version_name,
                    actual = "_" + is_micro_version_name,
                    visibility = ["//visibility:public"],
                )
                matches_minor_version_names[name].append(equals_micro_name)

        for name in _constraint_values(minor_to_plats[minor_version]).keys():
            # This is prefixed with an underscore to prevent confusion due to how
            # config_setting_group is implemented and how our micro-version targets
            # are named. config_setting_group will generate targets like
            # "is_python_3.10_1" (where the `_N` suffix is len(match_any).
            # Meanwhile, the micro-version tarets are named "is_python_3.10.1" --
            # just a single dot vs underscore character difference.
            selects.config_setting_group(
                name = "_is_python_" + minor_version + name,
                match_any = matches_minor_version_names[name],
            )

            native.alias(
                name = "is_python_" + minor_version + name,
                actual = "_is_python_" + minor_version,
                visibility = ["//visibility:public"],
            )
