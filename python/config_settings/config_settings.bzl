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

    allowed_flag_values = []
    for micro_version in python_versions:
        minor, _, _ = micro_version.rpartition(".")
        minor_to_micro_versions.setdefault(minor, []).append(micro_version)
        allowed_flag_values.append(micro_version)

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

    for minor_version, micro_versions in minor_to_micro_versions.items():
        _config_settings_for_minor_version(
            minor_version = minor_version,
            micro_versions = {
                v: [
                    _parse_platform(plat)
                    for plat in python_versions[v]
                ]
                for v in micro_versions
            },
        )

def _parse_platform(plat):
    cpu, _, os = plat.partition("-")
    if "linux" in os:
        os = "linux"
    elif "darwin" in os:
        os = "osx"
    elif "windows" in os:
        os = "windows"
    else:
        fail("unknown os: {}".format(os))

    return (os, cpu)

def _config_settings_for_minor_version(*, minor_version, micro_versions):
    """Constructs a set of configs for all Python versions.
    """
    matches_minor_version_names = {}
    constraint_values_by_suffix = {}

    for micro_version, plats in micro_versions.items():
        for suffix, constraint_values in _constraint_values(plats).items():
            matches_micro_version = _micro_version_condition(
                micro_version = micro_version,
                suffix = suffix,
                constraint_values = constraint_values,
            )
            matches_minor_version_names.setdefault(suffix, []).append(matches_micro_version)
            constraint_values_by_suffix[suffix] = constraint_values

    for suffix, constraint_values in constraint_values_by_suffix.items():
        # This matches the raw flag value, e.g. --//python/config_settings:python_version=3.8
        # It's private because matching the concept of e.g. "3.8" value is done
        # using the `is_python_X.Y` config setting group, which is aware of the
        # minor versions that could match instead.
        equals_minor_version = "_python_version_flag_equals_" + minor_version + suffix
        native.config_setting(
            name = equals_minor_version,
            flag_values = {":python_version": minor_version},
            constraint_values = constraint_values,
        )
        matches_minor_version_names[suffix].append(equals_minor_version)

        # This is prefixed with an underscore to prevent confusion due to how
        # config_setting_group is implemented and how our micro-version targets
        # are named. config_setting_group will generate targets like
        # "is_python_3.10_1" (where the `_N` suffix is len(match_any).
        # Meanwhile, the micro-version tarets are named "is_python_3.10.1" --
        # just a single dot vs underscore character difference.
        selects.config_setting_group(
            name = "_is_python_" + minor_version + suffix,
            match_any = matches_minor_version_names[suffix],
        )

        native.alias(
            name = "is_python_" + minor_version + suffix,
            actual = "_is_python_" + minor_version + suffix,
            visibility = ["//visibility:public"],
        )

def _constraint_values(plats):
    """For a list of (os, cpu) tuples get all possible platform names and constraint values.
    """
    ret = {
        # This is the no platform constraint values version
        "": [],
    }
    os_cpus = []
    for (os, cpu) in plats:
        # Normalize the cpu names to the ones present in the `@platforms//cpu`
        if cpu == "ppc64le":
            cpu = "ppc"

        if (os, None) not in os_cpus:
            # Add only the OS constraint value
            os_cpus.append((os, None))
        if (None, cpu) not in os_cpus:
            # Add only the CPU constraint value
            os_cpus.append((None, cpu))

        # Add both OS and CPU constraint values
        os_cpus.append((os, cpu))

    for (os, cpu) in os_cpus:
        constraint_values = []
        parts = [""]
        if os:
            constraint_values.append("@platforms//os:{}".format(os))
            parts.append(os)
        if cpu:
            constraint_values.append("@platforms//cpu:{}".format(cpu))
            parts.append(cpu)

        ret["_".join(parts)] = constraint_values

    return ret

def _micro_version_condition(*, micro_version, suffix, constraint_values):
    minor_version, _, _ = micro_version.rpartition(".")
    is_micro_version_name = "is_python_" + micro_version + suffix
    if MINOR_MAPPING[minor_version] != micro_version:
        native.config_setting(
            name = is_micro_version_name,
            flag_values = {":python_version": micro_version},
            constraint_values = constraint_values,
            visibility = ["//visibility:public"],
        )
        return is_micro_version_name

    # Ensure that is_python_3.9.8 is matched if python_version is set
    # to 3.9 if MINOR_MAPPING points to 3.9.8
    equals_micro_name = "_python_version_flag_equals_" + micro_version + suffix
    equals_minor_name = "_python_version_flag_equals_" + minor_version + suffix
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
            equals_minor_name,
        ],
    )
    native.alias(
        name = is_micro_version_name,
        actual = "_" + is_micro_version_name,
        visibility = ["//visibility:public"],
    )
    return equals_micro_name
