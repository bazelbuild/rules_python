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

"""TODO"""

load("@bazel_features//:features.bzl", "bazel_features")
load("//python/private:auth.bzl", "get_auth")

def simpleapi_download(module_ctx, srcs, cache = None):
    """Download Simple API HTML.

    Args:
        module_ctx: The bzlmod module_ctx.
        srcs: The sources to download things for.
        cache: A dictionary that can be used as a cache between calls during a
            single evaluation of the extension.

    Returns:
        dict of pkg name to the HTML contents.
    """
    download_kwargs = {}
    if bazel_features.external_deps.download_has_block_param:
        download_kwargs["block"] = False

    downloads = {}
    contents = {}
    for pkg, args in srcs.items():
        output = module_ctx.path("{}/{}.html".format("pypi_index", pkg))
        all_urls = list(args["urls"].keys())
        cache_key = ""
        if cache != None:
            cache_key = ",".join(all_urls)
            if cache_key in cache:
                contents[pkg] = cache[cache_key]
                continue

        downloads[pkg] = struct(
            out = output,
            urls = all_urls,
            cache_key = cache_key,
            download = module_ctx.download(
                url = all_urls,
                output = output,
                auth = get_auth(module_ctx, all_urls),
                **download_kwargs
            ),
        )

    for pkg, download in downloads.items():
        if download_kwargs.get("block") == False:
            result = download.download.wait()
        else:
            result = download.download

        if not result.success:
            fail("Failed to download from {}: {}".format(download.urls, result))

        content = module_ctx.read(download.out)
        contents[pkg] = struct(
            html = content,
            urls = download.urls,
        )

        if cache != None and download.cache_key:
            cache[download.cache_key] = contents[pkg]

    return contents
