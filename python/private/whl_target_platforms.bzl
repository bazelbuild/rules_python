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
A starlark implementation of the wheel platform tag parsing to get the target platform.
"""

# The order of the dictionaries is to keep definitions with their aliases next to each
# other
_CPU_ALIASES = {
    "x86_32": "x86_32",
    "i386": "x86_32",
    "i686": "x86_32",
    "x86": "x86_32",
    "x86_64": "x86_64",
    "amd64": "x86_64",
    "aarch64": "aarch64",
    "arm64": "aarch64",
    "ppc": "ppc",
    "ppc64le": "ppc",
    "s390x": "s390x",
}  # buildifier: disable=unsorted-dict-items

_OS_PREFIXES = {
    "linux": "linux",
    "manylinux": "linux",
    "musllinux": "linux",
    "macos": "osx",
    "win": "windows",
}  # buildifier: disable=unsorted-dict-items

def whl_target_platforms(platform_tag, abi_tag = ""):
    """Parse the wheel abi and platform tags and return (os, cpu) tuples.

    Args:
        platform_tag (str): The platform_tag part of the wheel name. See
            ./parse_whl_name.bzl for more details.
        abi_tag (str): The abi tag that should be used for parsing.

    Returns:
        A list of structs, with attributes:
        * os: str, one of the _OS_PREFIXES values
        * cpu: str, one of the _CPU_PREFIXES values
        * abi: str, the ABI that the interpreter should have if it is passed.
        * target_platform: str, the target_platform that can be given to the
          wheel_installer for parsing whl METADATA.
    """
    cpus = _cpu_from_tag(platform_tag)

    abi = None
    if abi_tag not in ["", "none", "abi3"]:
        abi = abi_tag

    for prefix, os in _OS_PREFIXES.items():
        if platform_tag.startswith(prefix):
            return [
                struct(
                    os = os,
                    cpu = cpu,
                    abi = abi,
                    target_platform = "_".join([abi, os, cpu] if abi else [os, cpu]),
                )
                for cpu in cpus
            ]

    fail("unknown platform_tag os: {}".format(platform_tag))

def _cpu_from_tag(tag):
    candidate = [
        cpu
        for input, cpu in _CPU_ALIASES.items()
        if tag.endswith(input)
    ]
    if candidate:
        return candidate

    if tag == "win32":
        return ["x86_32"]
    elif tag.endswith("universal2") and tag.startswith("macosx"):
        return ["x86_64", "aarch64"]
    else:
        fail("Unrecognized tag: '{}': cannot determine CPU".format(tag))
