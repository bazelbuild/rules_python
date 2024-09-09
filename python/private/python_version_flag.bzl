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

"""python_version related code.
"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _ver_key(s):
    major, _, s = s.partition(".")
    minor, _, s = s.partition(".")
    micro, _, s = s.partition(".")
    return (int(major), int(minor), int(micro))

def flag_values(python_versions, minor_mapping):
    """Construct a map of python_version to a list of toolchain values.

    This mapping maps the concept of a config setting to a list of compatible toolchain versions.
    For using this in the code, the VERSION_FLAG_VALUES should be used instead.

    Args:
        python_versions: list of strings; all X.Y.Z python versions.
        minor_mapping: minor version to full version mapping.

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
        default_micro_version = minor_mapping[minor_version]
        ret[micro_version] = [micro_version, minor_version] if default_micro_version == micro_version else [micro_version]

    return ret

def _python_version_flag_impl(ctx):
    value = ctx.build_setting_value
    if value not in ctx.attr.values:
        fail((
            "Invalid --python_version value: {actual}\nAllowed values {allowed}"
        ).format(
            actual = value,
            allowed = ", ".join(sorted(ctx.attr.values)),
        ))

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

python_version_flag = rule(
    implementation = _python_version_flag_impl,
    build_setting = config.string(flag = True),
    attrs = {
        "values": attr.string_list(
            doc = "Allowed values.",
        ),
    },
)
