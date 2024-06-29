# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""todo"""

load("//python/uv/private:toolchains_repo.bzl", "UV_PLATFORMS", "uv_toolchains_repo")
load("//python/uv/private:versions.bzl", "UV_TOOL_VERSIONS")

UV_BUILD_TMPL = """\
# Generated by repositories.bzl
load("@rules_python//python/uv:toolchain.bzl", "uv_toolchain")

uv_toolchain(
    name = "uv_toolchain",
    uv = "{binary}",
    version = "{version}",
)
"""

def _uv_repo_impl(repository_ctx):
    platform = repository_ctx.attr.platform
    uv_version = repository_ctx.attr.uv_version

    suffix = ".zip" if "windows" in platform else ".tar.gz"
    filename = "uv-{platform}{suffix}".format(
        platform = platform,
        suffix = suffix,
    )
    url = "https://github.com/astral-sh/uv/releases/download/{version}/{filename}".format(
        version = uv_version,
        filename = filename,
    )
    if filename.endswith(".tar.gz"):
        strip_prefix = filename[:-len(".tar.gz")]
    else:
        strip_prefix = ""

    repository_ctx.download_and_extract(
        url = url,
        #integrity = UV_TOOL_VERSIONS[repository_ctx.attr.uv_version][repository_ctx.attr.platform],
        stripPrefix = strip_prefix,
    )

    binary = "uv.exe" if platform.startswith("windows_") else "uv"
    repository_ctx.file(
        "BUILD.bazel",
        UV_BUILD_TMPL.format(
            binary = binary,
            version = uv_version,
        ),
    )

uv_repository = repository_rule(
    _uv_repo_impl,
    doc = "Fetch external tools needed for uv toolchain",
    attrs = {
        "platform": attr.string(mandatory = True, values = UV_PLATFORMS.keys()),
        "uv_version": attr.string(mandatory = True, values = UV_TOOL_VERSIONS.keys()),
    },
)

# Wrapper macro around everything above, this is the primary API
def uv_register_toolchains(name, register = True, **kwargs):
    """Convenience macro for users which does typical setup.

    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "uv0_2_13"
        register: whether to call through to native.register_toolchains.
            Should be True for WORKSPACE users, but false when used under bzlmod extension
        **kwargs: passed to each uv_repositories call
    """
    for platform in UV_PLATFORMS.keys():
        uv_repository(
            name = name + "_" + platform,
            platform = platform,
            **kwargs
        )
        if register:
            native.register_toolchains("@%s_toolchains//:%s_toolchain" % (name, platform))

    uv_toolchains_repo(
        name = name + "_toolchains",
        user_repository_name = name,
    )
