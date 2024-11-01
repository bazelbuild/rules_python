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

"""A function to convert a dist name to a valid bazel repo name.
"""

load("//python/private:normalize_name.bzl", "normalize_name")
load(":parse_whl_name.bzl", "parse_whl_name")

def _normalize_version(version):
    version = version.replace("-", ".")
    version = version.replace("+", "_")
    return version

def whl_repo_name(prefix, filename):
    """Return a valid whl_library repo name given a distribution filename.

    Args:
        prefix: str, the prefix of the whl_library.
        filename: str, the filename of the distribution.

    Returns:
        a string that can be used in `whl_library`.
    """
    parts = [prefix]

    if not filename.endswith(".whl"):
        # Then the filename is basically foo-3.2.1.<ext>
        name, _, version_with_ext = filename.rpartition("-")
        parts.append(normalize_name(name))
        parts.append(_normalize_version(version_with_ext))
    else:
        parsed = parse_whl_name(filename)
        name = normalize_name(parsed.distribution)
        version = _normalize_version(parsed.version)
        python_tag, _, _ = parsed.python_tag.partition(".")
        abi_tag, _, _ = parsed.abi_tag.partition(".")
        platform_tag, _, _ = parsed.platform_tag.partition(".")

        parts.append(name)
        parts.append(version)
        parts.append(python_tag)
        parts.append(abi_tag)
        parts.append(platform_tag)

    return "_".join(parts)
