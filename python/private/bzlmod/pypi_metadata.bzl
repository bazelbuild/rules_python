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

"""PyPI metadata hub and spoke repos"""

def whl_lock(name, *requirements, **kwargs):
    indexes = kwargs.get("indexes", ["https://pypi.org/simple"])

    sha_by_pkg = {}
    for requirement in requirements:
        sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]
        distribution, _, _ = requirement.partition("==")
        distribution, _, _ = distribution.partition("[")

        if distribution not in sha_by_pkg:
            sha_by_pkg[distribution] = {}

        for sha in sha256s:
            sha_by_pkg[distribution][sha] = True

    pass

def _whl_lock_impl(rctx):
    fail("TODO")

_whl_lock = repository_rule(
    attrs = {
    },
    implementation = _whl_lock_impl,
)

def _pypi_metadata_impl(rctx):
    fail("TODO")

pypi_metadata = repository_rule(
    attrs = {
    },
    implementation = _pypi_metadata_impl,
)

def _pypi_distribution_metadata_impl(rctx):
    fail("TODO")

pypi_distribution_metadata = repository_rule(
    attrs = {
    },
    implementation = _pypi_distribution_metadata_impl,
)
