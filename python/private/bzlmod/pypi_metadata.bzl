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
load(":label.bzl", _label = "label")
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
        label = _label(label) if type(label) == type("") else label,
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
    for module in module_ctx.modules:
        for attr in module.tags.experimental_target_platforms:
            if not module.is_root:
                fail("setting target platforms is only supported in root modules")

            enabled = attr.enabled
            break

    if not enabled:
        return None

    all_requirements = []
    indexes = {}
    for module in module_ctx.modules:
        for pip_attr in module.tags.parse:
            extra_args = pip_attr.extra_pip_args
            for requirements_lock in [
                pip_attr.requirements_lock,
                pip_attr.requirements_linux,
                pip_attr.requirements_darwin,
                pip_attr.requirements_windows,
            ]:
                if not requirements_lock:
                    continue

                requirements_lock_content = module_ctx.read(requirements_lock)
                parse_result = parse_requirements(requirements_lock_content)
                requirements = parse_result.requirements
                all_requirements.extend([line for _, line in requirements])

                extra_pip_args = extra_args + parse_result.options
                indexes.update({
                    index: True
                    for index in _get_indexes_from_args(extra_pip_args)
                })

    sha256s_by_distribution = {}
    for requirement in all_requirements:
        sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]
        distribution, _, _ = requirement.partition("==")
        distribution, _, _ = distribution.partition("[")
        distribution = normalize_name(distribution.strip())

        if distribution not in sha256s_by_distribution:
            sha256s_by_distribution[distribution] = {}

        for sha in sha256s:
            sha256s_by_distribution[distribution][sha] = True

    metadata = _fetch_metadata(
        module_ctx,
        sha256s_by_distribution = sha256s_by_distribution,
        indexes = indexes.keys(),
    )

    ret = {}

    for distribution, metadata in metadata.items():
        files = {}

        for file in metadata.files:
            _, _, filename = file.url.rpartition("/")
            archive_name = "{}_{}_{}".format(name, distribution, file.sha256[:6])

            # We would use http_file, but we are passing the URL to use via a file,
            # if the url is known (in case of using pdm lock), we could use an
            # http_file.
            pypi_file(
                name = archive_name,
                sha256 = file.sha256,
                patches = {
                    p: json.encode(args)
                    for p, args in whl_overrides.get(distribution, {}).items()
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
        got_urls = _fetch_urls_from_index(module_ctx, index_url, want, "index-{}".format(i))

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

def _fetch_urls_from_index(module_ctx, index_url, need_to_download, fname_prefix = "pypi"):
    download_kwargs = {}

    has_non_blocking_downloads = bazel_features.external_deps.download_has_block_param
    if has_non_blocking_downloads:
        download_kwargs["block"] = False

    downloads = {}
    for distribution in need_to_download:
        downloads[distribution] = {}
        html = "{}-{}.html".format(fname_prefix, distribution)
        download = module_ctx.download(
            url = index_url + "/" + distribution,
            output = html,
            **download_kwargs
        )

        if not has_non_blocking_downloads and not download.success:
            fail(download)

        if has_non_blocking_downloads:
            downloads[distribution] = (download, html)
        else:
            downloads[distribution] = html

    if has_non_blocking_downloads:
        for distribution, (download, html) in downloads.items():
            result = download.wait()
            if not result.success:
                fail(result)

            downloads[distribution] = html

    got_urls = {}
    for distribution, html in downloads.items():
        got_urls[distribution] = {}
        contents = module_ctx.read(html)
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

def _get_indexes_from_args(args):
    indexes = {"https://pypi.org/simple": True}
    next_is_index = False
    for arg in args:
        arg = arg.strip()
        if next_is_index:
            next_is_index = False
            index = arg.strip("/")
            if index not in indexes:
                indexes.append(index)

            continue

        if arg in ["--index-url", "-i", "--extra-index-url"]:
            next_is_index = True
            continue

        if "=" not in arg:
            continue

        index = None
        for index_arg_prefix in ["--index-url=", "--extra-index-url="]:
            if arg.startswith(index_arg_prefix):
                index = arg[len(index_arg_prefix):]
                break

        indexes[index] = True

    return indexes.keys()
