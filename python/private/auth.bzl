# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Helpers copied from http_file source to be reused here.

The implementation below is copied directly from Bazel's implementation of `http_archive`.
Accordingly, the return value of this function should be used identically as the `auth` parameter of `http_archive`.
Reference: https://github.com/bazelbuild/bazel/blob/6.3.2/tools/build_defs/repo/http.bzl#L109
"""

# TODO @aignas 2023-12-18: use the following instead when available.
# load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "read_netrc", "read_user_netrc", "use_netrc")

def get_auth(rctx, urls):
    """Utility for retrieving netrc-based authentication parameters for repository download rules used in python_repository.

    Args:
        rctx (repository_ctx): The repository rule's context object.
        urls: A list of URLs from which assets will be downloaded.

    Returns:
        dict: A map of authentication parameters by URL.
    """
    attr = getattr(rctx, "attr", None)

    if getattr(attr, "netrc", None):
        netrc = read_netrc(rctx, getattr(attr, "netrc"))
    elif "NETRC" in rctx.os.environ:
        netrc = read_netrc(rctx, rctx.os.environ["NETRC"])
    else:
        netrc = read_user_netrc(rctx)

    return use_netrc(netrc, urls, getattr(attr, "auth_patterns", ""))
