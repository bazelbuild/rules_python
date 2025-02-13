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

"""This module is for implementing PEP508 environment definition.
"""

load("//python/private:normalize_name.bzl", "normalize_name")

_platform_machine_values = {
    "aarch64": "arm64",
    "ppc": "ppc64le",
    "s390x": "s390x",
    "x86_32": "i386",
    "x86_64": "x86_64",
}
_platform_system_values = {
    "linux": "Linux",
    "osx": "Darwin",
    "windows": "Windows",
}
_sys_platform_values = {
    "linux": "posix",
    "osx": "darwin",
    "windows": "win32",
}
_os_name_values = {
    "linux": "posix",
    "osx": "posix",
    "windows": "nt",
}

def env(target_platform):
    """Return an env target platform

    Args:
        target_platform: {type}`str` the target platform identifier, e.g.
            `cp33_linux_aarch64`

    Returns:
        A dict that can be used as `env` in the marker evaluation.
    """
    abi, _, tail = target_platform.partition("_")

    # TODO @aignas 2024-12-26: wire up the usage of the micro version
    minor, _, micro = abi[3:].partition(".")
    micro = micro or "0"
    os, _, cpu = tail.partition("_")

    # TODO @aignas 2025-02-13: consider moving this into config settings.

    # This is split by topic
    return {
        "os_name": _os_name_values.get(os, ""),
        "platform_machine": "aarch64" if (os, cpu) == ("linux", "aarch64") else _platform_machine_values.get(cpu, ""),
        "platform_system": _platform_system_values.get(os, ""),
        "sys_platform": _sys_platform_values.get(os, ""),
    } | {
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
        "platform_release": "",
        "platform_version": "",
    } | {
        "implementation_version": "3.{}.{}".format(minor, micro),
        "python_full_version": "3.{}.{}".format(minor, micro),
        "python_version": "3.{}".format(minor),
    }

def deps(name, *, requires_dist, target_platforms = []):
    """Parse the RequiresDist from wheel METADATA

    Args:
        name: {type}`str` the name of the wheel.
        requires_dist: {type}`list[str]` the list of RequiresDist lines from the
            METADATA file.

    Returns a struct with attributes:
        deps: {type}`list[str]` dependencies to include unconditionally.
        deps_select: {type}`dict[str, str]` dependencies to include on particular
            subset of target platforms.
    """
    return struct(
        deps = [normalize_name(d) for d in requires_dist],
        deps_select = {},
    )
