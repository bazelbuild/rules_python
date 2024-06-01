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
A simple helper to populate the distribution attributes for each entry returned
by the parse_requirements function.

TODO @aignas 2024-05-23: The name is up for bikeshedding. For the time being I
am keeping it together with parse_requirements.bzl.
"""

load(":whl_target_platforms.bzl", "select_whls")

def parse_requirements_add_dists(requirements_by_platform, index_urls, python_version, logger = None):
    """Populate dists based on the information from the PyPI index.

    This function will modify the given requirements_by_platform data structure.

    Args:
        requirements_by_platform: The result of parse_requirements function.
        index_urls: The result of simpleapi_download.
        python_version: The version of the python interpreter.
        logger: A logger for printing diagnostic info.
    """
    for whl_name, requirements in requirements_by_platform.items():
        for requirement in requirements:
            whls = []
            sdist = None

            # TODO @aignas 2024-05-22: it is in theory possible to add all
            # requirements by version instead of by sha256. This may be useful
            # for some projects.
            for sha256 in requirement.srcs.shas:
                # For now if the artifact is marked as yanked we just ignore it.
                #
                # See https://packaging.python.org/en/latest/specifications/simple-repository-api/#adding-yank-support-to-the-simple-api

                maybe_whl = index_urls[whl_name].whls.get(sha256)
                if maybe_whl and not maybe_whl.yanked:
                    whls.append(maybe_whl)
                    continue

                maybe_sdist = index_urls[whl_name].sdists.get(sha256)
                if maybe_sdist and not maybe_sdist.yanked:
                    sdist = maybe_sdist
                    continue

                if logger:
                    logger.warn("Could not find a whl or an sdist with sha256={}".format(sha256))

            # Filter out the wheels that are incompatible with the target_platforms.
            whls = select_whls(
                whls = whls,
                want_abis = [
                    "none",
                    "abi3",
                    "cp" + python_version.replace(".", ""),
                    # Older python versions have wheels for the `*m` ABI.
                    "cp" + python_version.replace(".", "") + "m",
                ],
                want_platforms = requirement.target_platforms,
                want_python_version = python_version,
                logger = logger,
            )

            requirement.whls.extend(whls)
            if sdist:
                requirement.sdists.append(sdist)
