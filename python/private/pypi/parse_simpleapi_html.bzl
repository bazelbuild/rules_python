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
Parse SimpleAPI HTML in Starlark.
"""

def parse_simpleapi_html(*, url, content):
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
    sdists = {}
    whls = {}
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

    # Each line follows the following pattern
    # <a href="https://...#sha256=..." attribute1="foo" ... attributeN="bar">filename</a><br />
    for line in lines[1:]:
        dist_url, _, tail = line.partition("#sha256=")
        sha256, _, tail = tail.partition("\"")

        # See https://packaging.python.org/en/latest/specifications/simple-repository-api/#adding-yank-support-to-the-simple-api
        yanked = "data-yanked" in line

        # Metadata is of the form attribute="foo". Find pairs of open and associated
        # closed quotes marking each metadata attribute. Keep track of the latest
        # closing quote. Only afterwards we can use the next '>' to partition.
        valid_quotation = True
        last_closing_quote_idx = -1
        for idx in range(len(tail)):
            char = tail[idx]
            if char == "\"":
                valid_quotation = not valid_quotation
                if valid_quotation:
                    last_closing_quote_idx = idx
        if not valid_quotation:
            fail("Invalid metadata in line: {}".format(tail))
        maybe_metadata = tail[:last_closing_quote_idx + 1]
        tail = tail[last_closing_quote_idx + 1:]
        _, _, tail = tail.partition(">")
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

        if filename.endswith(".whl"):
            whls[sha256] = struct(
                filename = filename,
                url = _absolute_url(url, dist_url),
                sha256 = sha256,
                metadata_sha256 = metadata_sha256,
                metadata_url = _absolute_url(url, metadata_url),
                yanked = yanked,
            )
        else:
            sdists[sha256] = struct(
                filename = filename,
                url = _absolute_url(url, dist_url),
                sha256 = sha256,
                metadata_sha256 = "",
                metadata_url = "",
                yanked = yanked,
            )

    return struct(
        sdists = sdists,
        whls = whls,
    )

def _absolute_url(index_url, candidate):
    if not candidate.startswith(".."):
        return candidate

    candidate_parts = candidate.split("..")
    last = candidate_parts[-1]
    for _ in range(len(candidate_parts) - 1):
        index_url, _, _ = index_url.rstrip("/").rpartition("/")

    return "{}/{}".format(index_url, last.strip("/"))
