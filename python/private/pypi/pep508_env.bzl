# Copyright 2025 The Bazel Authors. All rights reserved.
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

# See https://stackoverflow.com/questions/45125516/possible-values-for-uname-m
_platform_machine_aliases = {
    # These pairs mean the same hardware, but different values may be used
    # on different host platforms.
    "amd64": "x86_64",
    "arm64": "aarch64",
    "i386": "x86_32",
    "i686": "x86_32",
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

def env(target_platform, *, extra = None):
    """Return an env target platform

    Args:
        target_platform: {type}`str` the target platform identifier, e.g.
            `cp33_linux_aarch64`
        extra: {type}`str` the extra value to be added into the env.

    Returns:
        A dict that can be used as `env` in the marker evaluation.
    """

    # TODO @aignas 2025-02-13: consider moving this into config settings.

    env = {"extra": extra} if extra != None else {}
    env = env | {
        "implementation_name": "cpython",
        "platform_python_implementation": "CPython",
        "platform_release": "",
        "platform_version": "",
    }

    if type(target_platform) == type(""):
        target_platform = platform_from_str(target_platform, python_version = "")

    if target_platform.abi:
        minor_version, _, micro_version = target_platform.abi[3:].partition(".")
        micro_version = micro_version or "0"
        env = env | {
            "implementation_version": "3.{}.{}".format(minor_version, micro_version),
            "python_full_version": "3.{}.{}".format(minor_version, micro_version),
            "python_version": "3.{}".format(minor_version),
        }
    if target_platform.os and target_platform.arch:
        os = target_platform.os
        env = env | {
            "os_name": _os_name_values.get(os, ""),
            "platform_machine": target_platform.arch,
            "platform_system": _platform_system_values.get(os, ""),
            "sys_platform": _sys_platform_values.get(os, ""),
        }

    # This is split by topic
    return env | {
        "_aliases": {
            "platform_machine": _platform_machine_aliases,
        },
    }

def platform(*, abi = None, os = None, arch = None):
    return struct(
        abi = abi,
        os = os,
        arch = arch,
    )

def platform_from_str(p, python_version):
    """Return a platform from a string.

    Args:
        p: {type}`str` the actual string.
        python_version: {type}`str` the python version to add to platform if needed.

    Returns:
        A struct that is returned by the `_platform` function.
    """
    if p.startswith("cp"):
        abi, _, p = p.partition("_")
    elif python_version:
        major, _, tail = python_version.partition(".")
        abi = "cp{}{}".format(major, tail)
    else:
        abi = None

    os, _, arch = p.partition("_")
    return platform(abi = abi, os = os or None, arch = arch or None)
