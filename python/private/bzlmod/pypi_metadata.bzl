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
load(":label.bzl", "label")
load("//python/private:text_util.bzl", "render")

whl_lock = module_extension(
    implementation = _pip_impl,
    tag_classes = {
)

def whl_lock(name, requirements, **kwargs):
    indexes = kwargs.get("indexes", ["https://pypi.org/simple"])

    sha_by_pkg = {}
    for requirement in requirements:
        sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]
        distribution, _, _ = requirement.partition("==")
        distribution, _, _ = distribution.partition("[")
        distribution = normalize_name(distribution)

        if distribution not in sha_by_pkg:
            sha_by_pkg[distribution] = {}

        for sha in sha256s:
            sha_by_pkg[distribution][sha] = True

    # TODO @aignas 2023-12-10: make this global across all hub repos
    for distribution, shas in sha_by_pkg.items():
        pypi_distribution_metadata(
            name="{}_{}_metadata".format(name, distribution),
            distribution=distribution,
            sha256s=shas,
            indexes=indexes,
        )

    pypi_metadata(
        name="{}_metadata".format(name),
        distributions=sha_by_pkg.keys(),
    )

    _whl_lock(
        name = name,
        srcs = [
            label("@{}_{}_metadata//:metadata.json".format(name, distribution))
            for distribution in sha_by_pkg
        ],
    )

def _whl_lock_impl(rctx):
    lock = {}
    for src in rctx.attr.srcs:
        contents = json.decode(rctx.read(src))

        _, _, distribution = str(src).partition(rctx.attr.name)
        distribution, _, _ = distribution.rpartition("_metadata")
        distribution = distribution.strip("_")
        lock[distribution] = contents

    rctx.file("lock.json", json.encode(lock))
    rctx.file("BUILD.bazel", """exports_files(["lock.json"], visibility=["//visibility:public"])""")


_whl_lock = repository_rule(
    attrs = {
        "srcs": attr.label_list(),
    },
    implementation = _whl_lock_impl,
)

def _pypi_metadata_impl(rctx):
    aliases = {
        distribution: "@@{}_{}_metadata//:metadata.json".format(
            rctx.name.replace("_metadata", ""),
            distribution,
        )
        for distribution in rctx.attr.distributions
    }
    build_contents = [
        render.alias(name=name, actual=actual, visibility=["//visibility:public"])
        for name, actual in aliases.items()
    ]
    rctx.file("BUILD.bazel", "\n\n".join(build_contents))

pypi_metadata = repository_rule(
    attrs = {
        "distributions": attr.string_list(),
    },
    implementation = _pypi_metadata_impl,
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

    rctx.file("metadata.json", json.encode(struct(files=files)))
    rctx.file("BUILD.bazel", """exports_files(["metadata.json"], visibility=["//visibility:public"])""")

pypi_distribution_metadata = repository_rule(
    attrs = {
        "distribution": attr.string(),
        "indexes": attr.string_list(),
        "sha256s": attr.string_list(),
    },
    implementation = _pypi_distribution_metadata_impl,
)
