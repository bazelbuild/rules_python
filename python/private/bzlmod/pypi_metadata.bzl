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

load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("//python/private:normalize_name.bzl", "normalize_name")
load(":label.bzl", _label = "label")
load(":pypi_archive.bzl", "pypi_file")

def whl_files_from_requirements(module_ctx, *, name, whl_overrides = {}):
    all_requirements = []
    indexes = {"https://pypi.org/simple": True}
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

    sha_by_pkg = {}
    for requirement in all_requirements:
        sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]
        distribution, _, _ = requirement.partition("==")
        distribution, _, _ = distribution.partition("[")
        distribution = normalize_name(distribution.strip())

        if distribution not in sha_by_pkg:
            sha_by_pkg[distribution] = {}

        for sha in sha256s:
            sha_by_pkg[distribution][sha] = True

    metadata = _fetch_metadata(
        module_ctx,
        sha256s_by_distribution = sha_by_pkg,
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

            files[file.sha256] = struct(
                filename = filename,
                label = _label("@{}//:file".format(archive_name)),
                sha256 = file.sha256,
            )

        ret[normalize_name(distribution)] = struct(
            distribution = distribution,
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

def _fetch_metadata(module_ctx, *, sha256s_by_distribution, indexes = ["https://pypi.org/simple"]):
    download_kwargs = {}
    has_non_blocking_downloads = True
    if has_non_blocking_downloads:
        # NOTE @aignas 2023-12-15: this will only available in 7.1.0 and above
        # See https://github.com/bazelbuild/bazel/issues/19674
        download_kwargs["block"] = False

    downloads = {}
    for distribution in sha256s_by_distribution.keys():
        downloads[distribution] = {}
        for i, index_url in enumerate(indexes):
            html = "pypi-{}-{}.html".format(distribution, i)
            download = module_ctx.download(
                url = index_url + "/" + distribution,
                output = html,
                **download_kwargs
            )

            if not has_non_blocking_downloads and not download.success:
                fail(download)

            downloads[distribution][html] = download


    for distribution in sha256s_by_distribution:
        for html, download in downloads[distribution].items():
            if not has_non_blocking_downloads:
                continue

            result = download.wait()
            if not result.success:
                fail(result)

            downloads[distribution][html] = result

    ret = {}
    for distribution, want_shas in sha256s_by_distribution.items():
        files = {}

        for html, result in downloads[distribution].items():
            contents = module_ctx.read(html)

            _, _, hrefs = contents.partition("<a href=\"")
            for line in hrefs.split("<a href=\""):
                url, _, tail = line.partition("#")
                _, _, tail = tail.partition("=")
                sha256, _, tail = tail.partition("\"")
                if sha256 not in want_shas:
                    continue

                files[sha256] = struct(
                    url = url,
                    sha256 = sha256,
                )

        if not files:
            fail("Could not find any files for: {}".format(distribution))

        missing_shas = [sha for sha in want_shas if sha not in files]
        if missing_shas:
            fail("Could not find all of the {} files with shas: {}".format(distribution, missing_shas))

        ret[distribution] = struct(
            files = files.values(),
        )

    return ret

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
