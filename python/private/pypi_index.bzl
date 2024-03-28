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

load("@bazel_features//:features.bzl", "bazel_features")
load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load(":auth.bzl", "get_auth")
load(":envsubst.bzl", "envsubst")
load(":normalize_name.bzl", "normalize_name")

def simpleapi_download(module_ctx, *, index_url, index_url_overrides, sources, envsubst, cache = None):
    """Download Simple API HTML.

    Args:
        module_ctx: The bzlmod module_ctx.
        index_url: The index.
        index_url_overrides: The index overrides for separate packages.
        sources: The sources to download things for.
        envsubst: The envsubst vars.
        cache: A dictionary that can be used as a cache between calls during a
            single evaluation of the extension.

    Returns:
        dict of pkg name to the HTML contents.
    """
    sources = get_packages_from_requirements(sources)
    index_url_overrides = {
        normalize_name(p): i
        for p, i in (index_url_overrides or {}).items()
    }

    srcs = {}
    for pkg, want_shas in sources.simpleapi.items():
        entry = srcs.setdefault(pkg, {"urls": {}, "want_shas": {}})

        # ensure that we have a trailing slash, because we will otherwise get redirects
        # which may not work on private indexes with netrc authentication.
        entry["urls"]["{}/{}/".format(index_url_overrides.get(pkg, index_url).rstrip("/"), pkg)] = True
        entry["want_shas"].update(want_shas)

    download_kwargs = {}
    if bazel_features.external_deps.download_has_block_param:
        download_kwargs["block"] = False

    # Download in parallel if possible
    downloads = {}
    contents = {}
    for pkg, args in srcs.items():
        all_urls = list(args["urls"].keys())
        cache_key = ""
        if cache != None:
            # FIXME @aignas 2024-03-28: should I envsub this?
            cache_key = ",".join(all_urls)
            if cache_key in cache:
                contents[pkg] = cache[cache_key]
                continue

        downloads[pkg] = struct(
            cache_key = cache_key,
            urls = all_urls,
            packages = read_simple_api(
                module_ctx = module_ctx,
                url = all_urls,
                pkg = pkg,
                envsubst_vars = envsubst,
                **download_kwargs,
            ),
        )

    for pkg, download in downloads.items():
        contents[pkg] = download.packages.contents()

        if cache != None and download.cache_key:
            cache[download.cache_key] = contents[pkg]

    return contents

def read_simple_api(module_ctx, url, pkg, envsubst_vars, **download_kwargs):
    """Read SimpleAPI.

    Args:
        module_ctx: TODO
        url: The url parameter that can be passed to module_ctx.download.
        pkg: The pkg to fetch the data for.
        envsubst_vars: The env vars to do env sub before downloading.
        **download_kwargs: Any extra params to module_ctx.download.
            Note that output and auth will be passed for you.

    Returns:
        A similar object to what `download` would return except that in result.out
        will be the parsed simple api contents.
    """
    # TODO @aignas 2024-03-26: use a unique path to avoid clashes
    output = module_ctx.path("{}/{}.html".format("pypi_index", pkg))

    # TODO: Add a test that env subbed index urls do not leak into the lock file.
    if type(url) == type(""):
        fail("TODO")
    else:
        real_url = [
            envsubst(
                u,
                envsubst_vars,
                module_ctx.getenv if hasattr(module_ctx, "getenv") else module_ctx.os.environ.get,
            )
            for u in url
        ]

    download = module_ctx.download(
        url = real_url,
        output = output,
        auth = get_auth(module_ctx, real_url),
        **download_kwargs
    )

    return struct(
        contents=lambda: _read_contents(
            module_ctx,
            download.wait() if download_kwargs.get("block") == False else download,
            output,
            url,
        ),
    )


def _read_contents(module_ctx, result, output, url):
    if not result.success:
          fail("Failed to download from {}: {}".format(url, result))

    html = module_ctx.read(output)
    return get_packages(url, html)

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

    if head == line:
        head = line.partition("--hash=")[0].strip()
    else:
        head = head + ";" + maybe_hashes.partition("--hash=")[0].strip()

    return struct(
        wo_shas = line if not shas else head,
        version = version,
        shas = sorted(shas),
    )

def get_packages(index_urls, content, want_shas = None):
    """Get the package URLs for given shas by parsing the Simple API HTML.

    Args:
        index_urls(list[str]): The URLs that the HTML content can be downloaded from.
        content(str): The Simple API HTML content.
        want_shas(list[str], optional): The list of shas that we need to get, otherwise we'll get all.

    Returns:
        A list of structs with:
        * filename: The filename of the artifact.
        * url: The URL to download the artifact.
        * sha256: The sha256 of the artifact.
        * metadata_sha256: The whl METADATA sha256 if we can download it. If this is
          present, then the 'metadata_url' is also present. Defaults to "".
        * metadata_url: The URL for the METADATA if we can download it. Defaults to "".
    """
    want_shas = {sha: True for sha in want_shas} if want_shas else {}
    packages = []
    lines = content.split("<a href=\"")

    _, _, api_version = lines[0].partition("name=\"pypi:repository-version\" content=\"")
    api_version, _, _ = api_version.partition("\"")

    # We must assume the 1.0 if it is not present
    # See https://packaging.python.org/en/latest/specifications/simple-repository-api/#clients
    api_version = api_version or "1.0"
    api_version = tuple([int(i) for i in api_version.split(".")])

    if api_version >= (2, 0):
        # We don't expect to have version 2.0 here, but have this check in place just in case.
        # https://packaging.python.org/en/latest/specifications/simple-repository-api/#versioning-pypi-s-simple-api
        fail("Unsupported API version: {}".format(api_version))

    for line in lines[1:]:
        url, _, tail = line.partition("#sha256=")
        sha256, _, tail = tail.partition("\"")

        if want_shas:
            if sha256 not in want_shas:
                continue
            elif "data-yanked" in line:
                # See https://packaging.python.org/en/latest/specifications/simple-repository-api/#adding-yank-support-to-the-simple-api
                #
                # For now we just fail and inform the user to relock the requirements with a
                # different version.
                fail("The package with '--hash=sha256:{}' was yanked, relock your requirements".format(sha256))
            else:
                want_shas.pop(sha256)

        maybe_metadata, _, tail = tail.partition(">")
        filename, _, tail = tail.partition("<")

        metadata_marker = "data-core-metadata=\"sha256="
        if metadata_marker in maybe_metadata:
            # Implement https://peps.python.org/pep-0714/
            _, _, tail = maybe_metadata.partition(metadata_marker)
            metadata_sha256, _, _ = tail.partition("\"")
            metadata_url = url + ".metadata"
        else:
            metadata_sha256 = ""
            metadata_url = ""

        packages.append(
            struct(
                filename = filename,
                url = _absolute_urls(index_urls[0], url),
                sha256 = sha256,
                metadata_sha256 = metadata_sha256,
                metadata_url = metadata_url,
            ),
        )

    if len(want_shas):
        fail(
            "Indexes {} did not provide packages with all shas: {}".format(
                index_urls,
                ", ".join(want_shas.keys()),
            ),
        )

    return packages

def _absolute_urls(index_url, candidate):
    if not candidate.startswith(".."):
        return candidate

    candidate_parts = candidate.split("..")
    last = candidate_parts[-1]
    for _ in range(len(candidate_parts) - 1):
        index_url, _, _ = index_url.rstrip("/").rpartition("/")

    return "{}/{}".format(index_url, last.strip("/"))
