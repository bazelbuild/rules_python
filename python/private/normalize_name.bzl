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
Normalize a PyPI package name to allow consistent label names
"""

# Keep in sync with python/pip_install/tools/bazel.py
def normalize_name(name):
    """normalize a PyPI package name and return a valid bazel label.

    Note we chose `_` instead of `-` as a separator so that we can have more
    idiomatic bazel target names when using the output of this helper function.

    See
    https://packaging.python.org/en/latest/specifications/name-normalization/

    Args:
        name: the PyPI package name.

    Returns:
        a normalized name as a string.
    """
    name = name.replace("-", "_").replace(".", "_").lower()
    if "__" not in name:
        return name

    # Handle the edge-case where the package should be fixed, but at the same
    # time we should not be breaking.
    return "_".join([
        part
        for part in name.split("_")
        if part
    ])
