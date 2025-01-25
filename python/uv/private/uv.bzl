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

"""
EXPERIMENTAL: This is experimental and may be removed without notice

A module extension for working with uv.
"""

load(":uv_repositories.bzl", "uv_repositories")

_DOC = """\
A module extension for working with uv.

Use it in your own setup by:
```starlark
uv = use_extension(
    "@rules_python//python/uv:uv.bzl",
    "uv",
    dev_dependency = True,
)
uv.toolchain(
    name = "uv_toolchains",
    version = "0.5.24",
)
use_repo(uv, "uv_toolchains")

register_toolchains(
    "@uv_toolchains//:all",
    dev_dependency = True,
)
```

Since this is only for locking the requirements files, it should be always
marked as a `dev_dependency`.
"""

_DIST_MANIFEST_JSON = "dist-manifest.json"
_DEFAULT_BASE_URL = "https://github.com/astral-sh/uv/releases/download"

config = tag_class(
    doc = "Configure where the binaries are going to be downloaded from.",
    attrs = {
        "base_url": attr.string(
            doc = "Base URL to download metadata about the binaries and the binaries themselves.",
            default = _DEFAULT_BASE_URL,
        ),
    },
)

platform = tag_class(
    doc = "Configure the available platforms for lock file generation.",
    attrs = {
        "compatible_with": attr.label_list(
            doc = "The compatible with constraint values for toolchain resolution",
        ),
        "flag_values": attr.label_keyed_string_dict(
            doc = "The flag values for toolchain resolution",
        ),
        "name": attr.string(
            doc = "The platform string used in the UV repository to denote the platform triple.",
            mandatory = True,
        ),
    },
)

uv_toolchain = tag_class(
    doc = "Configure uv toolchain for lock file generation.",
    attrs = {
        "name": attr.string(
            doc = "The name of the toolchain repo",
            default = "uv_toolchains",
        ),
        "version": attr.string(
            doc = "Explicit version of uv.",
            mandatory = True,
        ),
    },
)

def _uv_toolchain_extension(module_ctx):
    config = {
        "platforms": {},
    }

    for mod in module_ctx.modules:
        if not mod.is_root and not mod.name == "rules_python":
            # Only rules_python and the root module can configure this.
            #
            # Ignore any attempts to configure the `uv` toolchain elsewhere
            #
            # Only the root module may configure the uv toolchain.
            # This prevents conflicting registrations with any other modules.
            #
            # NOTE: We may wish to enforce a policy where toolchain configuration is only allowed in the root module, or in rules_python. See https://github.com/bazelbuild/bazel/discussions/22024
            continue

        # Note, that the first registration will always win, giving priority to
        # the root module.

        for platform_attr in mod.tags.platform:
            config["platforms"].setdefault(platform_attr.name, struct(
                name = platform_attr.name.replace("-", "_").lower(),
                compatible_with = platform_attr.compatible_with,
                flag_values = platform_attr.flag_values,
            ))

        for config_attr in mod.tags.config:
            config.setdefault("base_url", config_attr.base_url)

        for toolchain in mod.tags.toolchain:
            config.setdefault("version", toolchain.version)
            config.setdefault("name", toolchain.name)

    if not config["version"]:
        return

    config.setdefault("base_url", _DEFAULT_BASE_URL)
    config["urls"] = _get_tool_urls_from_dist_manifest(
        module_ctx,
        base_url = "{base_url}/{version}".format(**config),
    )
    uv_repositories(
        name = config["name"],
        platforms = config["platforms"],
        urls = config["urls"],
        version = config["version"],
    )

def _get_tool_urls_from_dist_manifest(module_ctx, *, base_url):
    """Download the results about remote tool sources.

    This relies on the tools using the cargo packaging to infer the actual
    sha256 values for each binary.
    """
    dist_manifest = module_ctx.path(_DIST_MANIFEST_JSON)
    module_ctx.download(base_url + "/" + _DIST_MANIFEST_JSON, output = dist_manifest)
    dist_manifest = json.decode(module_ctx.read(dist_manifest))

    artifacts = dist_manifest["artifacts"]
    tool_sources = {}
    downloads = {}
    for fname, artifact in artifacts.items():
        if artifact.get("kind") != "executable-zip":
            continue

        checksum = artifacts[artifact["checksum"]]
        checksum_fname = checksum["name"]
        checksum_path = module_ctx.path(checksum_fname)
        downloads[checksum_path] = struct(
            download = module_ctx.download(
                "{}/{}".format(base_url, checksum_fname),
                output = checksum_path,
                block = False,
            ),
            archive_fname = fname,
            platforms = checksum["target_triples"],
        )

    for checksum_path, download in downloads.items():
        result = download.download.wait()
        if not result.success:
            fail(result)

        archive_fname = download.archive_fname

        sha256, _, checksummed_fname = module_ctx.read(checksum_path).partition(" ")
        checksummed_fname = checksummed_fname.strip(" *\n")
        if archive_fname != checksummed_fname:
            fail("The checksum is for a different file, expected '{}' but got '{}'".format(
                archive_fname,
                checksummed_fname,
            ))

        for platform in download.platforms:
            tool_sources[platform] = struct(
                urls = ["{}/{}".format(base_url, archive_fname)],
                sha256 = sha256,
            )

    return tool_sources

uv = module_extension(
    doc = _DOC,
    implementation = _uv_toolchain_extension,
    tag_classes = {
        "config": config,
        "platform": platform,
        "toolchain": uv_toolchain,
    },
)
