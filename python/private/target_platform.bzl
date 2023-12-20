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

_cpu_aliases = {
    "x86_64": "x86_64",
    "x86_32": "x86_32",
    "aarch64": "aarch64",
    "ppc": "ppc",
    "s390x": "s390x",
    # aliases
    "amd64": "x86_64",
    "arm64": "aarch64",
    "i386": "x86_32",
    "i686": "x86_32",
    "x86": "x86_32",
    "ppc64le": "ppc",
}  # buildifier: disable=unsorted-dict-items

_os_prefixes = {
    "linux": "linux",
    "manylinux": "linux",
    "musllinux": "linux",
    "macos": "osx",
    "win": "windows",
}  # buildifier: disable=unsorted-dict-items

def target_platform(tag):
    """Parse the wheel platform tag and return (os, cpu) tuples.

    Args:
        tag (str): The platform_tag part of the wheel name. See
            ./parse_whl_name.bzl for more details.

    Returns:
        A list of structs with os and cpu attributes.
    """
    cpus = _cpu_from_tag(tag)

    for prefix, os in _os_prefixes.items():
        if tag.startswith(prefix):
            return [
                struct(os = os, cpu = cpu)
                for cpu in cpus
            ]

    fail("unknown tag os: {}".format(tag))

def _cpu_from_tag(tag):
    candidate = [
        cpu
        for input, cpu in _cpu_aliases.items()
        if tag.endswith(input)
    ]
    if candidate:
        return candidate

    if tag == "win32":
        return ["x86_32"]
    elif tag.endswith("universal2") and tag.startswith("macosx"):
        return ["x86_64", "aarch64"]
    else:
        fail("unknown tag: {}".format(tag))
