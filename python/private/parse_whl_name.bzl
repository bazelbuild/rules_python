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

"""
A starlark implementation of a Wheel filename parsing.
"""

_LEGACY_ALIASES = {
    "manylinux1_i686": "manylinux_2_5_i686",
    "manylinux1_x86_64": "manylinux_2_5_x86_64",
    "manylinux2010_i686": "manylinux_2_12_i686",
    "manylinux2010_x86_64": "manylinux_2_12_x86_64",
    "manylinux2014_aarch64": "manylinux_2_17_aarch64",
    "manylinux2014_armv7l": "manylinux_2_17_armv7l",
    "manylinux2014_i686": "manylinux_2_17_i686",
    "manylinux2014_ppc64": "manylinux_2_17_ppc64",
    "manylinux2014_ppc64le": "manylinux_2_17_ppc64le",
    "manylinux2014_s390x": "manylinux_2_17_s390x",
    "manylinux2014_x86_64": "manylinux_2_17_x86_64",
}

_ARCH = {
    "aarch64": "aarch64",
    "amd64": "x86_64",
    "arm64": "aarch64",
    "armv7l": "aarch32",
    "i686": "x86_32",
    "ppc64": "ppc",
    "ppc64le": "ppc64le",
    "s390x": "s390x",
    "x86_64": "x86_64",
}

def parse_whl_name(file):
    """Parse whl file name into a struct of constituents.

    Args:
        file (str): The file name of a wheel

    Returns:
        A struct with the following attributes:
            distribution: the distribution name
            version: the version of the distribution
            build_tag: the build tag for the wheel. None if there was no
              build_tag in the given string.
            python_tag: the python tag for the wheel
            abi_tag: the ABI tag for the wheel
            platform_tag: the platform tag
    """
    if not file.endswith(".whl"):
        fail("not a valid wheel: {}".format(file))

    file = file[:-len(".whl")]

    # Parse the following
    # {distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl
    #
    # For more info, see the following standards:
    # https://packaging.python.org/en/latest/specifications/binary-distribution-format/#binary-distribution-format
    # https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/
    head, _, platform_tag = file.rpartition("-")
    if not platform_tag:
        fail("cannot extract platform tag from the whl filename: {}".format(file))
    head, _, abi_tag = head.rpartition("-")
    if not abi_tag:
        fail("cannot extract abi tag from the whl filename: {}".format(file))
    head, _, python_tag = head.rpartition("-")
    if not python_tag:
        fail("cannot extract python tag from the whl filename: {}".format(file))
    head, _, version = head.rpartition("-")
    if not version:
        fail("cannot extract version from the whl filename: {}".format(file))
    distribution, _, maybe_version = head.partition("-")

    if maybe_version:
        version, build_tag = maybe_version, version
    else:
        build_tag = None

    return struct(
        distribution = distribution,
        version = version,
        build_tag = build_tag,
        python_tag = python_tag,
        abi_tag = abi_tag,
        platform_tag = platform_tag,
    )

def _convert_from_legacy(platform_tag):
    return _LEGACY_ALIASES.get(platform_tag, platform_tag)

def whl_target_compatible_with(file):
    """Parse whl file and return compatibility list.

    Args:
        file (str): The file name of a wheel

    Returns:
        A list that can be put into target_compatible_with
    """
    parsed = parse_whl_name(file)

    if parsed.platform_tag == "any" and parsed.abi_tag == "none":
        return []

    # TODO @aignas 2023-11-16: add ABI handling

    platform, _, _ = parsed.platform_tag.partition(".")
    platform = _convert_from_legacy(platform)

    if platform.startswith("manylinux"):
        _, _, tail = platform.partition("_")

        _glibc_major, _, tail = tail.partition("_")  # Discard as this is currently unused
        _glibc_minor, _, arch = tail.partition("_")  # Discard as this is currently unused

        return [
            "@platforms//cpu:" + _ARCH.get(arch, arch),
            "@platforms//os:linux",
        ]
        # TODO @aignas 2023-11-16: figure out when this happens, perhaps it is when
        # we build a wheel instead ourselves instead of downloading it from PyPI?

    elif platform.startswith("linux_"):
        _, _, arch = platform.partition("_")

        return [
            "@platforms//cpu:" + _ARCH.get(arch, arch),
            "@platforms//os:linux",
        ]

    elif platform.startswith("macosx"):
        _, _, tail = platform.partition("_")

        _os_major, _, tail = tail.partition("_")  # Discard as this is currently unused
        _os_minor, _, arch = tail.partition("_")  # Discard as this is currently unused

        if arch.startswith("universal"):
            return ["@platforms//os:osx"]
        else:
            return [
                "@platforms//cpu:" + _ARCH.get(arch, arch),
                "@platforms//os:osx",
            ]
    elif platform.startswith("win"):
        if platform == "win32":
            return [
                "@platforms//cpu:x86_32",
                "@platforms//os:windows",
            ]
        elif platform == "win64":
            return [
                "@platforms//cpu:x86_32",
                "@platforms//os:windows",
            ]

        _, _, arch = platform.partition("_")

        return [
            "@platforms//cpu:" + _ARCH.get(arch, arch),
            "@platforms//os:windows",
        ]

    fail("Could not parse platform values for a wheel platform: '{}'".format(parsed))
