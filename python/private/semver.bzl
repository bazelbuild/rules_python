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

"A semver version parser"

def semver(version):
    """Parse the semver version and return the values as a struct.

    Args:
        version: {type}`str` the version string

    Returns:
        A {type}`struct` with `major`, `minor`, `patch` and `build` attributes.
    """
    major, _, version = version.partition(".")
    minor, _, version = version.partition(".")
    patch, _, build = version.partition("+")

    return struct(
        # use semver vocabulary here
        major = major,
        minor = minor,
        patch = patch,  # this is called `micro` in the Python interpreter versioning scheme
        build = build,
    )
