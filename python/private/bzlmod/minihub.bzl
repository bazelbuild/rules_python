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

"""The overall design is:

There is a single Pip hub repository, which creates the following repos:
* `whl_index` that downloads the SimpleAPI page for a particular package
  from the given indexes. It creates labels with URLs that can be used
  to download things. Args:
  * distribution - The name of the distribution.
  * version - The version of the package.
* `whl_archive` that downloads a particular wheel for a package, it accepts
  the following args:
  * sha256 - The sha256 to download.
  * url - The url to use. Optional.
  * url_file - The label that has the URL for downloading the wheel. Optional.
    Mutually exclusive with the url arg.
  * indexes - Indexes to query. Optional.
* `whl_library` that extracts a particular wheel.

This is created to make use of the parallelism that can be achieved if fetching
is done in separate threads, one for each external repository.
"""

def whl_library(name, requirement, python_version, python_interpreter_target, **kwargs):
    """Generate a number of third party repos for a particular wheel."""
    indexes = kwargs.get("indexes", ["https://pypi.org/simple"])
    sha256s = requirement.split("--hash=sha256:")[1:]
    distribution, _, version_and_tail = requirement.partition("==")
    version, _, _ = version_and_tail.partition(" ")

    # Defines targets:
    # * whl - depending on the platform, return the correct whl defined in "name_sha.whl"
    # * pkg - depending on the platform, return the correct py_library target in "name_sha"
    # * dist_info - depending on the platform, return the correct py_library target in "name_sha"
    # * data - depending on the platform, return the correct py_library target in "name_sha"
    whl_index(
        name = name,
        sha256s = sha256s,
        indexes = indexes,
        version = version,
        python_version = python_version,  # used to get the right wheels
    )

    for sha256 in sha256s:
        # We would use http_file, but we are passing the URL to use via a file,
        # if the url is known (in case of using pdm lock), we could use an
        # http_file.
        whl_archive(
            name = "{}_{}.whl".format(name, sha256),
            distribution = distribution,
            url_file = "{name}//:_{sha256}_url".format(name = name, sha256 = sha256),
        )

        _whl_library(
            name = "{name}_{sha256}".format(name = name, sha256 = sha256),
            file = "{name}_{sha256}//:whl".format(name = name, sha256 = sha256),
            python_interpreter_target = python_interpreter_target,
            **kwargs
        )
