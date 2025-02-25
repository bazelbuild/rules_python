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

load(":toolchain_types.bzl", "UV_TOOLCHAIN_TYPE")
load(":uv_repositories.bzl", "uv_repositories")
load(":uv_toolchains_repo.bzl", "uv_toolchains_repo")

_DOC = """\
A module extension for working with uv.

Basic usage:
```starlark
uv = use_extension(
    "@rules_python//python/uv:uv.bzl",
    "uv",
    # Use `dev_dependency` so that the toolchains are not defined pulled when
    # your module is used elsewhere.
    dev_dependency = True,
)
uv.configure(version = "0.5.24")
```

Since this is only for locking the requirements files, it should be always
marked as a `dev_dependency`.
"""

default = tag_class(
    doc = """\
Set the uv configuration defaults.
""",
    attrs = {
        "base_url": attr.string(
            doc = "Base URL to download metadata about the binaries and the binaries themselves.",
        ),
        "compatible_with": attr.label_list(
            doc = "The compatible with constraint values for toolchain resolution",
        ),
        "manifest_filename": attr.string(
            doc = "The manifest filename to for the metadata fetching.",
            default = "dist-manifest.json",
        ),
        "platform": attr.string(
            doc = "The platform string used in the UV repository to denote the platform triple.",
        ),
        "target_settings": attr.label_list(
            doc = "The `target_settings` to add to platform definitions.",
        ),
        "version": attr.string(
            doc = "The version of uv to use.",
        ),
    },
)

configure = tag_class(
    doc = """\
Build the UV toolchain configuration appending configuration to the last version configuration or starting a new version configuration if {attr}`version` is passed.

In addition to the very basic configuration pattern outlined above you can customize
the configuration:
```starlark
# Configure the base_url for the specified version.
uv.configure(base_url = "my_mirror")

# Add an extra platform that can be used with your version.
uv.configure(
    platform = "extra-platform",
    target_settings = ["//my_config_setting_label"],
    compatible_with = ["@platforms//os:exotic"],
)
```

::::tip
The configuration is additive for each version. This means that if you need to set
defaults for all versions, use the {attr}`default` for all of the configuration,
similarly how `rules_python` is doing it itself.
::::
""",
    attrs = {
        "base_url": attr.string(
            doc = "Base URL to download metadata about the binaries and the binaries themselves.",
        ),
        "compatible_with": attr.label_list(
            doc = "The compatible with constraint values for toolchain resolution",
        ),
        "manifest_filename": attr.string(
            doc = "The manifest filename to for the metadata fetching.",
            default = "dist-manifest.json",
        ),
        "platform": attr.string(
            doc = "The platform string used in the UV repository to denote the platform triple.",
        ),
        "target_settings": attr.label_list(
            doc = "The `target_settings` to add to platform definitions.",
        ),
        "version": attr.string(
            doc = "The version of uv to use.",
        ),
    },
)

def parse_modules(module_ctx, uv_repository = None):
    """Parse the modules to get the config for 'uv' toolchains.

    Args:
        module_ctx: the context.
        uv_repository: the rule to create a uv_repository override.

    Returns:
        A dictionary for each version of the `uv` to configure.
    """
    config = {
        "platforms": {},
    }

    for mod in module_ctx.modules:
        for default_attr in mod.tags.default:
            if default_attr.version:
                config["version"] = default_attr.version

            if default_attr.base_url:
                config["base_url"] = default_attr.base_url

            if default_attr.manifest_filename:
                config["manifest_filename"] = default_attr.manifest_filename

            if default_attr.platform and not (default_attr.compatible_with or default_attr.target_settings):
                config["platforms"].pop(default_attr.platform)
            elif default_attr.platform:
                config["platforms"].setdefault(
                    default_attr.platform,
                    struct(
                        name = default_attr.platform.replace("-", "_").lower(),
                        compatible_with = default_attr.compatible_with,
                        target_settings = default_attr.target_settings,
                    ),
                )
            elif default_attr.compatible_with or default_attr.target_settings:
                fail("TODO: unsupported")

    versions = {}
    for mod in module_ctx.modules:
        last_version = None
        for config_attr in mod.tags.configure:
            last_version = config_attr.version or last_version or config["version"]
            specific_config = versions.setdefault(last_version, {
                "base_url": config["base_url"],
                "manifest_filename": config["manifest_filename"],
                "platforms": {k: v for k, v in config["platforms"].items()},  # make a copy
            })
            if config_attr.platform and not (config_attr.compatible_with or config_attr.target_settings):
                specific_config["platforms"].pop(config_attr.platform)
            elif config_attr.platform:
                specific_config["platforms"][config_attr.platform] = struct(
                    name = config_attr.platform.replace("-", "_").lower(),
                    compatible_with = config_attr.compatible_with,
                    target_settings = config_attr.target_settings,
                )
            elif config_attr.compatible_with or config_attr.target_settings:
                fail("TODO: unsupported")

            if config_attr.base_url:
                specific_config["base_url"] = config_attr.base_url

            if config_attr.manifest_filename:
                config["manifest_filename"] = config_attr.manifest_filename

    versions = {
        v: config
        for v, config in versions.items()
        if config["platforms"]
    }
    if not versions:
        return struct(
            names = ["none"],
            labels = {
                # NOTE @aignas 2025-02-24: the label to the toolchain can be anything
                "none": str(Label("//python:none")),
            },
            compatible_with = {
                "none": ["@platforms//:incompatible"],
            },
            target_settings = {},
        )

    toolchain_names = []
    toolchain_labels_by_toolchain = {}
    toolchain_compatible_with_by_toolchain = {}
    toolchain_target_settings = {}

    for version, config in versions.items():
        config["urls"] = _get_tool_urls_from_dist_manifest(
            module_ctx,
            base_url = "{base_url}/{version}".format(
                version = version,
                base_url = config["base_url"],
            ),
            manifest_filename = config["manifest_filename"],
        )
        platforms = config["platforms"]
        result = uv_repositories(
            name = "uv",
            platforms = platforms,
            urls = config["urls"],
            version = version,
            uv_repository = uv_repository,
        )

        for name in result.names:
            platform = platforms[result.platforms[name]]

            toolchain_names.append(name)
            toolchain_labels_by_toolchain[name] = result.labels[name]
            toolchain_compatible_with_by_toolchain[name] = [
                str(label)
                for label in platform.compatible_with
            ]
            toolchain_target_settings[name] = [
                str(label)
                for label in platform.target_settings
            ]

    return struct(
        names = toolchain_names,
        labels = toolchain_labels_by_toolchain,
        compatible_with = toolchain_compatible_with_by_toolchain,
        target_settings = toolchain_target_settings,
    )

def _uv_toolchain_extension(module_ctx):
    toolchain = parse_modules(
        module_ctx,
    )

    uv_toolchains_repo(
        name = "uv",
        toolchain_type = str(UV_TOOLCHAIN_TYPE),
        toolchain_names = toolchain.names,
        toolchain_labels = toolchain.labels,
        toolchain_compatible_with = toolchain.compatible_with,
        toolchain_target_settings = toolchain.target_settings,
    )

def _get_tool_urls_from_dist_manifest(module_ctx, *, base_url, manifest_filename):
    """Download the results about remote tool sources.

    This relies on the tools using the cargo packaging to infer the actual
    sha256 values for each binary.
    """
    dist_manifest = module_ctx.path(manifest_filename)
    result = module_ctx.download(
        base_url + "/" + manifest_filename,
        output = dist_manifest,
    )
    if not result.success:
        fail(result)
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
        "configure": configure,
        "default": default,
    },
)
