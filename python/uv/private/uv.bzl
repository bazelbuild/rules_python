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

_DEFAULT_ATTRS = {
    "base_url": attr.string(
        doc = """\
Base URL to download metadata about the binaries and the binaries themselves.
""",
    ),
    "compatible_with": attr.label_list(
        doc = """\
The compatible with constraint values for toolchain resolution.
""",
    ),
    "manifest_filename": attr.string(
        doc = """\
The distribution manifest filename to use for the metadata fetching from GH. The
defaults for this are set in `rules_python` MODULE.bazel file that one can override
for a specific version.
""",
        default = "dist-manifest.json",
    ),
    "platform": attr.string(
        doc = """\
The platform string used in the UV repository to denote the platform triple.
""",
    ),
    "target_settings": attr.label_list(
        doc = """\
The `target_settings` to add to platform definitions that then get used in `toolchain`
definitions.
""",
    ),
    "version": attr.string(
        doc = """\
The version of uv to configure the sources for.
""",
    ),
}

default = tag_class(
    doc = """\
Set the uv configuration defaults.
""",
    attrs = _DEFAULT_ATTRS,
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

# Add an extra platform that can be used with your version.
uv.configure(
    platform = "patched-binary",
    target_settings = ["//my_super_config_setting"],
    urls = ["https://example.zip"],
    sha256 = "deadbeef",
)
```

::::tip
The configuration is additive for each version. This means that if you need to set
defaults for all versions, use the {attr}`default` for all of the configuration,
similarly how `rules_python` is doing it itself.
::::
""",
    attrs = _DEFAULT_ATTRS | {
        "sha256": attr.string(
            doc = "The sha256 of the downloaded artifact if the {attr}`urls` is specified.",
        ),
        "urls": attr.string_list(
            doc = """\
The urls to download the binary from. If this is used, {attr}`base_url` and
{attr}`manifest_name` are ignored for the given version.

::::note
If the `urls` are specified, they need to be specified for all of the platforms
for a particular version.
::::
""",
        ),
    },
)

def _configure(config, *, platform, compatible_with, target_settings, urls = [], sha256 = "", **values):
    """Set the value in the config if the value is provided"""
    for key, value in values.items():
        if not value:
            continue

        config[key] = value

    config.setdefault("platforms", {})
    if platform and not (compatible_with or target_settings or urls):
        config["platforms"].pop(platform)
    elif platform:
        if compatible_with or target_settings:
            config["platforms"][platform] = struct(
                name = platform.replace("-", "_").lower(),
                compatible_with = compatible_with,
                target_settings = target_settings,
            )
        if urls:
            config.setdefault("urls", {})[platform] = struct(
                sha256 = sha256,
                urls = urls,
            )
    elif compatible_with or target_settings:
        fail("`platform` name must be specified when specifying `compatible_with` or `target_settings`")

def process_modules(
        module_ctx,
        hub_name = "uv",
        uv_repository = None,
        toolchain_type = str(UV_TOOLCHAIN_TYPE),
        hub_repo = uv_toolchains_repo):
    """Parse the modules to get the config for 'uv' toolchains.

    Args:
        module_ctx: the context.
        hub_name: the name of the hub repository.
        uv_repository: the rule to create a uv_repository override.
        toolchain_type: the toolchain type to use here.
        hub_repo: the hub repo factory function to use.

    Returns:
        the result of the hub_repo. Mainly used for tests.
    """
    # default values to apply for version specific config
    defaults = {
        "base_url": "",
        "manifest_filename": "",
        "platforms": {
            # The structure is as follows:
            # "platform_name": struct(
            #     compatible_with = [],
            #     target_settings = [],
            # ),
            #
            # NOTE: urls and sha256 cannot be set in defaults
        },
        "version": "",
    }
    for mod in module_ctx.modules:
        for default_attr in mod.tags.default:
            _configure(
                defaults,
                version = default_attr.version,
                base_url = default_attr.base_url,
                manifest_filename = default_attr.manifest_filename,
                platform = default_attr.platform,
                compatible_with = default_attr.compatible_with,
                target_settings = default_attr.target_settings,
            )

    # resolved per-version configuration. The shape is something like:
    # versions = {
    #     "1.0.0": {
    #         "base_url": "",
    #         "manifest_filename": "",
    #         "platforms": {
    #             "platform_name": struct(
    #                 compatible_with = [],
    #                 target_settings = [],
    #                 urls = [], # can be unset
    #                 sha256 = "", # can be unset
    #             ),
    #         },
    #     },
    # }
    versions = {}
    for mod in module_ctx.modules:
        last_version = None
        for config_attr in mod.tags.configure:
            last_version = config_attr.version or last_version or defaults["version"]
            if not last_version:
                fail("version must be specified")

            specific_config = versions.setdefault(
                last_version,
                {
                    "base_url": defaults.get("base_url", ""),
                    "manifest_filename": defaults["manifest_filename"],
                    "platforms": dict(defaults["platforms"]),  # copy
                },
            )

            _configure(
                specific_config,
                base_url = config_attr.base_url,
                manifest_filename = config_attr.manifest_filename,
                platform = config_attr.platform,
                compatible_with = config_attr.compatible_with,
                target_settings = config_attr.target_settings,
                sha256 = config_attr.sha256,
                urls = config_attr.urls,
            )

    versions = {
        version: config
        for version, config in versions.items()
        if config["platforms"]
    }
    if not versions:
        return hub_repo(
            name = hub_name,
            toolchain_type = toolchain_type,
            toolchain_names = ["none"],
            toolchain_labels = {
                # NOTE @aignas 2025-02-24: the label to the toolchain can be anything
                "none": str(Label("//python:none")),
            },
            toolchain_compatible_with = {
                "none": ["@platforms//:incompatible"],
            },
            toolchain_target_settings = {},
        )

    toolchain_names = []
    toolchain_labels_by_toolchain = {}
    toolchain_compatible_with_by_toolchain = {}
    toolchain_target_settings = {}
    for version, config in versions.items():
        platforms = config["platforms"]

        # Use the manually specified urls
        urls = {
            platform: src
            for platform, src in config.get("urls", {}).items()
            if src.urls
        }

        # Or fallback to fetching them from GH manifest file
        # Example file: https://github.com/astral-sh/uv/releases/download/0.6.3/dist-manifest.json
        if not urls:
            urls = _get_tool_urls_from_dist_manifest(
                module_ctx,
                base_url = "{base_url}/{version}".format(
                    version = version,
                    base_url = config["base_url"],
                ),
                manifest_filename = config["manifest_filename"],
                platforms = sorted(platforms),
            )

        result = uv_repositories(
            name = "uv",
            platforms = {
                platform_name: platform
                for platform_name, platform in platforms.items()
                if platform_name in urls
            },
            urls = urls,
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

    return hub_repo(
        name = hub_name,
        toolchain_type = toolchain_type,
        toolchain_names = toolchain_names,
        toolchain_labels = toolchain_labels_by_toolchain,
        toolchain_compatible_with = toolchain_compatible_with_by_toolchain,
        toolchain_target_settings = toolchain_target_settings,
    )

def _uv_toolchain_extension(module_ctx):
    toolchain = process_modules(
        module_ctx,
    )

def _overlap(first_collection, second_collection):
    for x in first_collection:
        if x in second_collection:
            return True

    return False

def _get_tool_urls_from_dist_manifest(module_ctx, *, base_url, manifest_filename, platforms):
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
        if not _overlap(checksum["target_triples"], platforms):
            # we are not interested in this platform, so skip
            continue

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
