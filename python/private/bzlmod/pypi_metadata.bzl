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

load("//python/private:normalize_name.bzl", "normalize_name")

def whl_lock(requirements, **kwargs):
    indexes = kwargs.get("indexes", ["https://pypi.org/simple"])

    sha_by_pkg = {}
    for requirement in requirements:
        sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]
        distribution, _, _ = requirement.partition("==")
        distribution, _, _ = distribution.partition("[")
        distribution = normalize_name(distribution.strip())

        if distribution not in sha_by_pkg:
            sha_by_pkg[distribution] = {}

        for sha in sha256s:
            sha_by_pkg[distribution][sha] = True

    for distribution, shas in sha_by_pkg.items():
        pypi_distribution_metadata(
            name = "{}_metadata".format(distribution),
            distribution = distribution,
            sha256s = shas,
            indexes = indexes,
        )

def _pypi_distribution_metadata_impl(rctx):
    files = []
    want_shas = {sha: True for sha in rctx.attr.sha256s}
    for i, index_url in enumerate(rctx.attr.indexes):
        html = "index-{}.html".format(i)
        result = rctx.download(
            url = index_url + "/" + rctx.attr.distribution,
            output = html,
        )
        if not result.success:
            fail(result)

        contents = rctx.read(html)
        rctx.delete(html)

        _, _, hrefs = contents.partition("<a href=\"")
        for line in hrefs.split("<a href=\""):
            url, _, tail = line.partition("#")
            _, _, tail = tail.partition("=")
            sha256, _, tail = tail.partition("\"")
            if sha256 not in want_shas:
                continue

            files.append(struct(
                url = url,
                sha256 = sha256,
            ))

    if not files:
        fail("Could not find any files for: {}".format(rctx.attr.distribution))

    rctx.file("files.json", json.encode(struct(files = files)))
    rctx.file("BUILD.bazel", """exports_files(["files.json"], visibility=["//visibility:public"])""")

pypi_distribution_metadata = repository_rule(
    attrs = {
        "distribution": attr.string(),
        "indexes": attr.string_list(),
        "sha256s": attr.string_list(),
    },
    implementation = _pypi_distribution_metadata_impl,
)
