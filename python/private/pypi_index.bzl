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
"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load(":auth.bzl", "get_auth")
load(":envsubst.bzl", "envsubst")
load(":normalize_name.bzl", "normalize_name")

def simpleapi_download(ctx, *, attr, cache):
    """Download Simple API HTML.

    Args:
        ctx: The module_ctx or repository_ctx.
        attr: Contains the parameters for the download. They are grouped into a
          struct for better clarity. It must have attributes:
           * index_url: str, the index.
           * index_url_overrides: dict[str, str], the index overrides for
             separate packages.
           * extra_index_urls: Extra index URLs that will be looked up after
             the main is looked up.
           * sources: list[str], the sources to download things for. Each value is
             the contents of requirements files.
           * envsubst: list[str], the envsubst vars for performing substitution in index url.
           * netrc: The netrc parameter for ctx.download, see http_file for docs.
           * auth_patterns: The auth_patterns parameter for ctx.download, see
               http_file for docs.
        cache: A dictionary that can be used as a cache between calls during a
            single evaluation of the extension. We use a dictionary as a cache
            so that we can reuse calls to the simple API when evaluating the
            extension. Using the canonical_id parameter of the module_ctx would
            deposit the simple API responses to the bazel cache and that is
            undesirable because additions to the PyPI index would not be
            reflected when re-evaluating the extension unless we do
            `bazel clean --expunge`.

    Returns:
        dict of pkg name to the parsed HTML contents - a list of structs.
    """
    index_url_overrides = {
        normalize_name(p): i
        for p, i in (attr.index_url_overrides or {}).items()
    }

    download_kwargs = {}
    if bazel_features.external_deps.download_has_block_param:
        download_kwargs["block"] = False

    # Download in parallel if possible. This will download (potentially
    # duplicate) data for multiple packages if there is more than one index
    # available, but that is the price of convenience. However, that price
    # should be mostly negligible because the simple API calls are very cheap
    # and the user should not notice any extra overhead.
    #
    # If we are in synchronous mode, then we will use the first result that we
    # find.
    #
    # NOTE @aignas 2024-03-31: we are not merging results from multiple indexes
    # to replicate how `pip` would handle this case.
    async_downloads = {}
    contents = {}
    index_urls = [attr.index_url] + attr.extra_index_urls
    for pkg in get_packages_from_requirements(attr.sources):
        pkg_normalized = normalize_name(pkg)

        success = False
        for index_url in index_urls:
            result = read_simple_api(
                ctx = ctx,
                url = "{}/{}/".format(
                    index_url_overrides.get(pkg_normalized, index_url).rstrip("/"),
                    pkg,
                ),
                attr = attr,
                cache = cache,
                **download_kwargs
            )
            if download_kwargs.get("block") == False:
                # We will process it in a separate loop:
                async_downloads.setdefault(pkg_normalized, []).append(
                    struct(
                        pkg_normalized = pkg_normalized,
                        wait = result.wait,
                    ),
                )
                continue

            if result.success:
                contents[pkg_normalized] = result.output
                success = True
                break

        if not async_downloads and not success:
            fail("Failed to download metadata from urls: {}".format(
                ", ".join(index_urls),
            ))

    if not async_downloads:
        return contents

    # If we use `block` == False, then we need to have a second loop that is
    # collecting all of the results as they were being downloaded in parallel.
    for pkg, downloads in async_downloads.items():
        success = False
        for download in downloads:
            result = download.wait()

            if result.success and download.pkg_normalized not in contents:
                contents[download.pkg_normalized] = result.output
                success = True

        if not success:
            fail("Failed to download metadata from urls: {}".format(
                ", ".join(index_urls),
            ))

    return contents

def read_simple_api(ctx, url, attr, cache, **download_kwargs):
    """Read SimpleAPI.

    Args:
        ctx: The module_ctx or repository_ctx.
        url: str, the url parameter that can be passed to ctx.download.
        attr: The attribute that contains necessary info for downloading. The
          following attributes must be present:
           * envsubst: The envsubst values for performing substitutions in the URL.
           * netrc: The netrc parameter for ctx.download, see http_file for docs.
           * auth_patterns: The auth_patterns parameter for ctx.download, see
               http_file for docs.
        cache: A dict for storing the results.
        **download_kwargs: Any extra params to ctx.download.
            Note that output and auth will be passed for you.

    Returns:
        A similar object to what `download` would return except that in result.out
        will be the parsed simple api contents.
    """
    # NOTE @aignas 2024-03-31: some of the simple APIs use relative URLs for
    # the whl location and we cannot handle multiple URLs at once by passing
    # them to ctx.download if we want to correctly handle the relative URLs.
    # TODO: Add a test that env subbed index urls do not leak into the lock file.

    real_url = envsubst(
        url,
        attr.envsubst,
        ctx.getenv if hasattr(ctx, "getenv") else ctx.os.environ.get,
    )

    cache_key = real_url
    if cache_key in cache:
        return struct(success = True, output = cache[cache_key])

    output_str = envsubst(
        url,
        attr.envsubst,
        # Use env names in the subst values - this will be unique over
        # the lifetime of the execution of this function and we also use
        # `~` as the separator to ensure that we don't get clashes.
        {e: "~{}~".format(e) for e in attr.envsubst}.get,
    )

    # Transform the URL into a valid filename
    for char in [".", ":", "/", "\\", "-"]:
        output_str = output_str.replace(char, "_")

    output = ctx.path(output_str.strip("_").lower() + ".html")

    # NOTE: this may have block = True or block = False in the download_kwargs
    download = ctx.download(
        url = [real_url],
        output = output,
        auth = get_auth(ctx, [real_url], ctx_attr = attr),
        allow_fail = True,
        **download_kwargs
    )

    if download_kwargs.get("block") == False:
        # Simulate the same API as ctx.download has
        return struct(
            wait = lambda: _read_index_result(ctx, download.wait(), output, url, cache, cache_key),
        )

    return _read_index_result(ctx, download, output, url, cache, cache_key)

def _read_index_result(ctx, result, output, url, cache, cache_key):
    if not result.success:
        return struct(success = False)

    content = ctx.read(output)

    output = parse_simple_api_html(url = url, content = content)
    if output:
        cache.setdefault(cache_key, output)
        return struct(success = True, output = output, cache_key = cache_key)
    else:
        return struct(success = False)

def get_packages_from_requirements(requirements_files):
    """Get Simple API sources from a list of requirements files and merge them.

    Args:
        requirements_files(list[str]): A list of requirements files contents.

    Returns:
        A list.
    """
    want_packages = sets.make()
    for contents in requirements_files:
        parse_result = parse_requirements(contents)
        for distribution, _ in parse_result.requirements:
            # NOTE: we'll be querying the PyPI servers multiple times if the
            # requirements contains non-normalized names, but this is what user
            # is specifying to us.
            sets.insert(want_packages, distribution)

    return sets.to_list(want_packages)

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
        requirement = line if not shas else head,
        version = version,
        shas = sorted(shas),
    )

def parse_simple_api_html(*, url, content):
    """Get the package URLs for given shas by parsing the Simple API HTML.

    Args:
        url(str): The URL that the HTML content can be downloaded from.
        content(str): The Simple API HTML content.

    Returns:
        A list of structs with:
        * filename: The filename of the artifact.
        * url: The URL to download the artifact.
        * sha256: The sha256 of the artifact.
        * metadata_sha256: The whl METADATA sha256 if we can download it. If this is
          present, then the 'metadata_url' is also present. Defaults to "".
        * metadata_url: The URL for the METADATA if we can download it. Defaults to "".
    """
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
        dist_url, _, tail = line.partition("#sha256=")
        sha256, _, tail = tail.partition("\"")

        # See https://packaging.python.org/en/latest/specifications/simple-repository-api/#adding-yank-support-to-the-simple-api
        yanked = "data-yanked" in line

        maybe_metadata, _, tail = tail.partition(">")
        filename, _, tail = tail.partition("<")

        metadata_sha256 = ""
        metadata_url = ""
        for metadata_marker in ["data-core-metadata", "data-dist-info-metadata"]:
            metadata_marker = metadata_marker + "=\"sha256="
            if metadata_marker in maybe_metadata:
                # Implement https://peps.python.org/pep-0714/
                _, _, tail = maybe_metadata.partition(metadata_marker)
                metadata_sha256, _, _ = tail.partition("\"")
                metadata_url = dist_url + ".metadata"
                break

        packages.append(
            struct(
                filename = filename,
                url = _absolute_url(url, dist_url),
                sha256 = sha256,
                metadata_sha256 = metadata_sha256,
                metadata_url = _absolute_url(url, metadata_url),
                yanked = yanked,
            ),
        )

    return packages

def _absolute_url(index_url, candidate):
    if not candidate.startswith(".."):
        return candidate

    candidate_parts = candidate.split("..")
    last = candidate_parts[-1]
    for _ in range(len(candidate_parts) - 1):
        index_url, _, _ = index_url.rstrip("/").rpartition("/")

    return "{}/{}".format(index_url, last.strip("/"))
