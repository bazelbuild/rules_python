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

load("@bazel_features//:features.bzl", "bazel_features")
load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("//python/private:normalize_name.bzl", "normalize_name")
load(":pypi_archive.bzl", "pypi_file")

def PyPISource(*, filename, label, sha256):
    """Create a PyPISource struct.

    Args:
        filename(str): The filename of the source.
        label(str or Label): The label to the source.
        sha256(str): The sha256 of the source, useful for matching against the `requirements` line.

    Returns:
        struct with filename(str), label(Label) and sha256(str) attributes
    """
    return struct(
        filename = filename,
        label = label,
        sha256 = sha256,
    )

def whl_files_from_requirements(module_ctx, *, name, whl_overrides = {}):
    """Fetch archives for all requirements files using the bazel downloader.

    Args:
        module_ctx: The module_ctx struct from the extension.
        name: The prefix of the fetched archive repos.
        whl_overrides: patches to be applied after fetching.

    Returns:
        a dict with the fetched metadata to be used later when creating hub and spoke repos.
    """
    enabled = False
    indexes = []
    for module in module_ctx.modules:
        for attr in module.tags.experimental_target_platforms:
            if not module.is_root:
                fail("setting target platforms is only supported in root modules")

            enabled = attr.enabled
            for index in [attr.index_url] + attr.extra_index_urls:
                if index not in indexes:
                    indexes.append(index)
            break

    if not enabled:
        return None

    requirements_files = [
        requirements_lock
        for module in module_ctx.modules
        for pip_attr in module.tags.parse
        for requirements_lock in [
            pip_attr.requirements_lock,
            pip_attr.requirements_linux,
            pip_attr.requirements_darwin,
            pip_attr.requirements_windows,
        ]
        if requirements_lock
    ]

    sha256s_by_distribution = {}
    for requirements_lock in requirements_files:
        requirements_lock_content = module_ctx.read(requirements_lock)
        parse_result = parse_requirements(requirements_lock_content)
        for distribution, line in parse_result.requirements:
            sha256s = [sha.strip() for sha in line.split("--hash=sha256:")[1:]]
            distribution = normalize_name(distribution)

            if distribution not in sha256s_by_distribution:
                sha256s_by_distribution[distribution] = {}

            for sha in sha256s:
                sha256s_by_distribution[distribution][sha] = True

    metadata = _fetch_metadata(
        module_ctx,
        sha256s_by_distribution = sha256s_by_distribution,
        indexes = indexes,
    )

    ret = {}

    for distribution, metadata in metadata.items():
        files = {}

        for file in metadata.files:
            _, _, filename = file.url.rpartition("/")
            archive_name = "{}_{}_{}".format(name, distribution, file.sha256[:6])

            # We could use http_file, but we want to also be able to patch the whl
            # file, which is something http_file does not know how to do.
            # if the url is known (in case of using pdm lock), we could use an
            # http_file.

            pypi_file(
                name = archive_name,
                sha256 = file.sha256,
                # FIXME @aignas 2023-12-18: consider if we should replace this
                # with http_file + whl_library from pycross that philsc is
                # working on. In the long term, it may be easier to maintain, especially
                # since this implementation needs to copy functionality around credential
                # helpers, etc to be useful.
                patches = {
                    patch_file: patch_dst.patch_strip
                    for patch_file, patch_dst in whl_overrides.get(distribution, {}).items()
                    if filename in patch_dst.whls
                },
                urls = [file.url],
                # FIXME @aignas 2023-12-15: add usage of the DEFAULT_PYTHON_VERSION
                # to get the hermetic interpreter
            )

            files[file.sha256] = PyPISource(
                filename = filename,
                label = "@{}//:file".format(archive_name),
                sha256 = file.sha256,
            )

        ret[normalize_name(distribution)] = struct(
            distribution = distribution,
            files = files,
        )

    return ret

def _fetch_metadata(module_ctx, *, sha256s_by_distribution, indexes):
    # Create a copy that is mutable within this context and use it like a queue
    want = {
        d: {sha: True for sha in shas.keys()}
        for d, shas in sha256s_by_distribution.items()
    }
    got = {}

    for i, index_url in enumerate(indexes):
        # Fetch from each index one by one so that we could do less work when fetching from the next index.
        download_kwargs = {}
        if bazel_features.external_deps.download_has_block_param:
            download_kwargs["block"] = False

        got_urls = _fetch_urls_from_index(
            module_ctx,
            index_url = index_url,
            need_to_download = want,
            fname_prefix = "index-{}".format(i),
            **download_kwargs
        )

        for distribution, shas in got_urls.items():
            if distribution not in got:
                got[distribution] = {}

            for sha256, url in shas.items():
                got[distribution][sha256] = url
                want[distribution].pop(sha256)

            if not want[distribution]:
                want.pop(distribution)

    if want:
        fail("Could not find files for: {}".format(want))

    return {
        distribution: struct(
            files = [
                struct(
                    url = url,
                    sha256 = sha256,
                )
                for sha256, url in urls.items()
            ],
        )
        for distribution, urls in got.items()
    }

def _fetch_urls_from_index(module_ctx, *, index_url, need_to_download, fname_prefix, **download_kwargs):
    downloads = {}
    for distribution in need_to_download:
        downloads[distribution] = {}
        fname = "{}-{}.html".format(fname_prefix, distribution)
        download = module_ctx.download(
            url = index_url + "/" + distribution,
            output = fname,
            **download_kwargs
        )

        if not download_kwargs.get("block", True):
            downloads[distribution] = (download, fname)
        elif not download.success:
            fail(download)
        else:
            downloads[distribution] = fname

    if not download_kwargs.get("block", True):
        for distribution, (download, fname) in downloads.items():
            result = download.wait()
            if not result.success:
                fail(result)

            downloads[distribution] = fname

    got_urls = {}
    for distribution, fname in downloads.items():
        got_urls[distribution] = {}
        contents = module_ctx.read(fname)
        got_shas = _parse_simple_api(contents, need_to_download[distribution])
        for sha256, url in got_shas:
            got_urls[distribution][sha256] = url

    return got_urls

def _parse_simple_api(html, want_shas):
    got = []

    _, _, hrefs = html.partition("<a href=\"")
    for line in hrefs.split("<a href=\""):
        url, _, tail = line.partition("#")
        _, _, tail = tail.partition("=")
        sha256, _, tail = tail.partition("\"")
        if want_shas and sha256 not in want_shas:
            continue

        got.append((sha256, url))

    return got
