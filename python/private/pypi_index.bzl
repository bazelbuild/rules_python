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

"""
A file that houses private functions used in the `bzlmod` extension with the same name.

The functions here should not depend on the `module_ctx` for easy unit testing.
"""

load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("//python/private:normalize_name.bzl", "normalize_name")

def get_packages_from_requirements(requirements_files):
    """Get Simple API sources from a list of requirements files and merge them.

    Args:
        requirements_files(list[str]): A list of requirements files contents.

    Returns:
        A struct with `simpleapi` attribute that contains a dict of normalized package
        name to a list of shas that we should index.
    """
    want_packages = {}
    for contents in requirements_files:
        parse_result = parse_requirements(contents)
        for distribution, line in parse_result.requirements:
            want_packages.setdefault(normalize_name(distribution), {}).update({
                # TODO @aignas 2024-03-07: use sets
                sha: True
                for sha in get_simpleapi_sources(line).shas
            })

    return struct(
        simpleapi = want_packages,
    )

def get_simpleapi_sources(line):
    """Get PyPI sources from a requirements.txt line.

    We interpret the spec described in
    https://pip.pypa.io/en/stable/reference/requirement-specifiers/#requirement-specifiers

    Args:
        line(str): The requirements.txt entry.

    Returns:
        A struct with shas attribute containing a list of shas to download from pypi_index.
    """
    head, _, maybe_hashes = line.partition(";")
    _, _, version = head.partition("==")
    version = version.partition(" ")[0].strip()

    if "@" in head:
        shas = []
    else:
        maybe_hashes = maybe_hashes or line
        shas = [
            sha.strip()
            for sha in maybe_hashes.split("--hash=sha256:")[1:]
        ]

    return struct(version = version, shas = sorted(shas))
