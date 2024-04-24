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

# Taken from https://peps.python.org/pep-0600/
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

# _translate_cpu and _translate_os from @platforms//host:extension.bzl
def _translate_cpu(arch):
    if arch in ["i386", "i486", "i586", "i686", "i786", "x86"]:
        return "x86_32"
    if arch in ["amd64", "x86_64", "x64"]:
        return "x86_64"
    if arch in ["ppc", "ppc64", "ppc64le"]:
        return "ppc"
    if arch in ["arm", "armv7l"]:
        return "arm"
    if arch in ["aarch64"]:
        return "aarch64"
    if arch in ["s390x", "s390"]:
        return "s390x"
    if arch in ["mips64el", "mips64"]:
        return "mips64"
    if arch in ["riscv64"]:
        return "riscv64"
    return None

def _translate_os(os):
    if os.startswith("mac os"):
        return "osx"
    if os.startswith("freebsd"):
        return "freebsd"
    if os.startswith("openbsd"):
        return "openbsd"
    if os.startswith("linux"):
        return "linux"
    if os.startswith("windows"):
        return "windows"
    return None

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
        # This is just a big value that should be larger than any other value returned by this function
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

def select_whl(*, whls, want_abis, want_os, want_cpu):
    """Select a suitable wheel from a list.

    Args:
        whls(list[struct]): A list of candidates.
        want_abis(list[str]): A list of ABIs that are supported.
        want_os(str): The module_ctx.os.name.
        want_cpu(str): The module_ctx.os.arch.

    Returns:
        None or a struct with `url`, `sha256` and `filename` attributes for the
        selected whl. If no match is found, None is returned.
    """
    if not whls:
        return None

    candidates = {}
    for whl in whls:
        parsed = parse_whl_name(whl.filename)
        if parsed.abi_tag not in want_abis:
            # Filter out incompatible ABIs
            continue

        platform_tags = list({_LEGACY_ALIASES.get(p, p): True for p in parsed.platform_tag.split(".")})

        for tag in platform_tags:
            candidates[tag] = whl

    # For most packages - if they supply 'any' wheel and there are no other
    # compatible wheels with the selected abis, we can just return the value.
    if len(candidates) == 1 and "any" in candidates:
        return struct(
            url = candidates["any"].url,
            sha256 = candidates["any"].sha256,
            filename = candidates["any"].filename,
        )

    target_plats = {}
    has_any = "any" in candidates
    for platform_tag, whl in candidates.items():
        if platform_tag == "any":
            continue

        if "musl" in platform_tag:
            # Ignore musl wheels for now
            continue

        platform_tag = ".".join({_LEGACY_ALIASES.get(p, p): True for p in platform_tag.split(".")})
        platforms = whl_target_platforms(platform_tag)
        for p in platforms:
            target_plats.setdefault("{}_{}".format(p.os, p.cpu), []).append(platform_tag)

    for p, platform_tags in target_plats.items():
        if has_any:
            platform_tags.append("any")

        target_plats[p] = sorted(platform_tags, key = _whl_priority)

    want = target_plats.get("{}_{}".format(
        _translate_os(want_os),
        _translate_cpu(want_cpu),
    ))
    if not want:
        return want

    return candidates[want[0]]

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
