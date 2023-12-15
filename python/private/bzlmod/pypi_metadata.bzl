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
load(":label.bzl", _label = "label")
load(":minihub.bzl", "pypi_archive")

def whl_files_from_requirements(*, name, requirements, indexes, whl_overrides = {}):
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

    ret = {}
    for distribution, shas in sha_by_pkg.items():
        metadata = "{}_metadata__{}".format(name, distribution)
        pypi_distribution_metadata(
            name = metadata,
            distribution = distribution,
            sha256s = shas,
            indexes = indexes,
        )

        metadata = _label("@{}//:metadata.json".format(metadata))

        files = {}
        for sha256 in shas:
            archive_name = "{}_{}_{}".format(name, distribution, sha256[:6])
            files[sha256] = _label("@{}//:file".format(archive_name))

            # We would use http_file, but we are passing the URL to use via a file,
            # if the url is known (in case of using pdm lock), we could use an
            # http_file.
            pypi_archive(
                name = archive_name,
                metadata = metadata,
                sha256 = sha256,
                patches = {
                    p: json.encode(args)
                    for p, args in whl_overrides.get(distribution, {}).items()
                },
                # FIXME @aignas 2023-12-15: add usage of the DEFAULT_PYTHON_VERSION
                # to get the hermetic interpreter
            )

        ret[distribution] = struct(
            metadata = metadata,
            files = files,
        )

    # return a {
    #    <distribution>: struct(
    #        metadata = <label for the PyPI simple index metadata>
    #        files = {
    #            <sha256>: <label> for the archive
    #        }
    #    )
    # }
    return ret

def fetch_metadata(ctx, *, distribution, sha256s, indexes = ["https://pypi.org/simple"]):
    files = []
    metadata = None

    want_shas = {sha: True for sha in sha256s}
    for i, index_url in enumerate(indexes):
        html = "index-{}.html".format(i)
        result = ctx.download(
            url = index_url + "/" + distribution,
            output = html,
        )
        if not result.success:
            fail(result)

        contents = ctx.read(html)
        #ctx.delete(html)

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

            # NOTE @aignas 2023-12-15: not sure why we would need it at this
            # point, just showing that it is possible to get it as well.
            metadata = metadata or _fetch_whl_metadata(ctx, url, line)

    if not files:
        fail("Could not find any files for: {}".format(distribution))

    got_shas = {f.sha256: True for f in files}
    missing_shas = [sha for sha in want_shas if sha not in got_shas]

    if missing_shas:
        fail("Could not find any files for {} for shas: {}".format(distribution, missing_shas))

    return struct(
        files = files,
        metadata = metadata,
    )

def _fetch_whl_metadata(ctx, url, line):
    """Fetch whl metadata if available

    See https://peps.python.org/pep-0658/
    See https://peps.python.org/pep-0714/
    """
    _, _, whl_metadata_sha256 = line.partition("data-core-metadata=\"sha256=")
    whl_metadata_sha256, _, _ = whl_metadata_sha256.partition("\"")

    if not whl_metadata_sha256:
        return None

    output = "whl_metadata.txt"
    ctx.download(
        url = url + ".metadata",
        output = output,
        sha256 = whl_metadata_sha256,
    )
    contents = ctx.read(output)

    requires_dist = []
    provides_extras = []

    for line in contents.split("\n"):
        if line.startswith("Requires-Dist"):
            requires_dist.append(line[len("Requires-Dist:"):].strip())
        elif line.startswith("Provides-Extra"):
            provides_extras.append(line[len("Provides-Extra:"):].strip())

    return struct(
        requires_dist = requires_dist,
        provides_extras = provides_extras,
    )

def _pypi_distribution_metadata_impl(rctx):
    metadata = fetch_metadata(
        rctx,
        distribution = rctx.attr.distribution,
        sha256s = rctx.attr.sha256s,
        indexes = rctx.attr.indexes,
    )

    rctx.file("metadata.json", json.encode(metadata))
    rctx.file("BUILD.bazel", """exports_files(["metadata.json"], visibility=["//visibility:public"])""")

pypi_distribution_metadata = repository_rule(
    attrs = {
        "distribution": attr.string(),
        "indexes": attr.string_list(),
        "sha256s": attr.string_list(),
    },
    implementation = _pypi_distribution_metadata_impl,
)
