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

load(":parse_whl_name.bzl", "parse_whl_name")

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
    "ppc64": "ppc",
    "ppc64le": "ppc",
    "s390x": "s390x",
    "arm": "arm",
    "armv6l": "arm",
    "armv7l": "arm",
}  # buildifier: disable=unsorted-dict-items

_OS_PREFIXES = {
    "linux": "linux",
    "manylinux": "linux",
    "musllinux": "linux",
    "macos": "osx",
    "win": "windows",
}  # buildifier: disable=unsorted-dict-items

def _whl_priority(value):
    """Return a value for sorting whl lists.

    TODO @aignas 2024-03-29: In the future we should create a repo for each
    repo that matches the abi and then we could have config flags for the
    preference of `any` wheels or `sdist` or `manylinux` vs `musllinux` or
    `universal2`. Ideally we use `select` statements in the hub repo to do
    the selection based on the config, but for now this is the best way to
    get this working for the host platform.

    In the future the right thing would be to have `bool_flag` or something
    similar to be able to have select statements that does the right thing:
    * select whls vs sdists.
    * select manylinux vs musllinux
    * select universal2 vs arch-specific whls

    All of these can be expressed as configuration settings and included in the
    select statements in the `whl` repo. This means that the user can configure
    for a particular target what they need.

    Returns a 4-tuple where the items are:
        * bool - is it an 'any' wheel? True if it is.
        * bool - is it an 'universal' wheel? True if it is. (e.g. macos universal2 wheels)
        * int - the minor plaform version (e.g. osx os version, libc version)
        * int - the major plaform version (e.g. osx os version, libc version)
    """
    if "." in value:
        value, _, _ = value.partition(".")

    if "any" == value:
        return (True, False, 0, 0)

    if "linux" in value:
        os, _, tail = value.partition("_")
        if os == "linux":
            # If the platform tag starts with 'linux', then return something less than what 'any' returns
            minor = 0
            major = 0
        else:
            major, _, tail = tail.partition("_")  # We don't need to use that because it's the same for all candidates now
            minor, _, _ = tail.partition("_")

        return (False, os == "linux", int(minor), int(major))

    if "mac" in value or "osx" in value:
        _, _, tail = value.partition("_")
        major, _, tail = tail.partition("_")
        minor, _, _ = tail.partition("_")

        return (False, "universal2" in value, int(minor), int(major))

    if not "win" in value:
        fail("BUG: only windows, linux and mac platforms are supported, but got: {}".format(value))

    # Windows does not have multiple wheels for the same target platform
    return (False, False, 0, 0)

def select_whls(*, whls, want_version = None, want_abis = [], want_platforms = []):
    """Select a subset of wheels suitable for target platforms from a list.

    Args:
        whls(list[struct]): A list of candidates.
        want_version(str, optional): An optional parameter to filter whls by version.
        want_abis(list[str]): A list of ABIs that are supported.
        want_platforms(str): The platforms

    Returns:
        None or a struct with `url`, `sha256` and `filename` attributes for the
        selected whl. If no match is found, None is returned.
    """
    if not whls:
        return {}

    version_limit = -1
    if want_version:
        version_limit = int(want_version.split(".")[1])

    candidates = {}
    any_whls = []
    for whl in whls:
        parsed = parse_whl_name(whl.filename)

        if want_abis and parsed.abi_tag not in want_abis:
            # Filter out incompatible ABIs
            continue

        if parsed.platform_tag == "any" or not want_platforms:
            whl_version_min = 0
            if parsed.python_tag.startswith("cp3"):
                whl_version_min = int(parsed.python_tag[len("cp3"):])

            if version_limit != -1 and whl_version_min > version_limit:
                continue
            elif version_limit != -1 and parsed.abi_tag in ["none", "abi3"]:
                # We want to prefer by version and then we want to prefer abi3 over none
                any_whls.append((whl_version_min, parsed.abi_tag == "abi3", whl))
                continue

            candidates["any"] = whl
            continue

        compatible = False
        for p in whl_target_platforms(parsed.platform_tag):
            if p.target_platform in want_platforms:
                compatible = True
                break

        if compatible:
            candidates[parsed.platform_tag] = whl

    if any_whls:
        # Overwrite the previously select any whl with the best fitting one.
        # The any_whls will be only populated if we pass the want_version
        # parameter.
        _, _, whl = sorted(any_whls)[-1]
        candidates["any"] = whl

    return candidates.values()

def select_whl(*, whls, want_platform):
    """Select a suitable wheel from a list.

    Args:
        whls(list[struct]): A list of candidates.
        want_platform(str): The target platform.

    Returns:
        None or a struct with `url`, `sha256` and `filename` attributes for the
        selected whl. If no match is found, None is returned.
    """
    if not whls:
        return None

    # TODO @aignas 2024-05-23: once we do the selection in the hub repo using
    # an actual select, then this function will be the one that is used within
    # the repository context instead of `select_whl`.
    whls = select_whls(
        whls = whls,
        want_platforms = [want_platform],
    )

    candidates = {
        parse_whl_name(w.filename).platform_tag: w
        for w in whls
        if "musllinux_" not in w.filename
    }

    target_whl_platform = sorted(
        candidates.keys(),
        key = _whl_priority,
    )
    if not target_whl_platform:
        return None

    return candidates[target_whl_platform[0]]

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

    print("WARNING: ignoring unknown platform_tag os: {}".format(platform_tag))  # buildifier: disable=print
    return []

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
    elif tag == "win_ia64":
        return []
    elif tag.startswith("macosx"):
        if tag.endswith("universal2"):
            return ["x86_64", "aarch64"]
        elif tag.endswith("universal"):
            return ["x86_64", "aarch64"]
        elif tag.endswith("intel"):
            return ["x86_32"]

    return []
