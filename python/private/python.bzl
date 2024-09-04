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

"Python toolchain module extensions for use with bzlmod."

load("@bazel_features//:features.bzl", "bazel_features")
load("//python:versions.bzl", "DEFAULT_RELEASE_BASE_URL", "MINOR_MAPPING", "PLATFORMS", "TOOL_VERSIONS")
load(":auth.bzl", "AUTH_ATTRS")
load(":full_version.bzl", "full_version")
load(":python_repositories.bzl", "python_register_toolchains")
load(":pythons_hub.bzl", "hub_repo")
load(":repo_utils.bzl", "repo_utils")
load(":semver.bzl", "semver")
load(":text_util.bzl", "render")
load(":toolchains_repo.bzl", "multi_toolchain_aliases")
load(":util.bzl", "IS_BAZEL_6_4_OR_HIGHER")

# This limit can be increased essentially arbitrarily, but doing so will cause a rebuild of all
# targets using any of these toolchains due to the changed repository name.
_MAX_NUM_TOOLCHAINS = 9999
_TOOLCHAIN_INDEX_PAD_LENGTH = len(str(_MAX_NUM_TOOLCHAINS))

def parse_mods(*, mctx, logger, debug = False, fail = fail):
    """parse_mods returns a struct with parsed tag class content.

    Args:
        mctx: {type}`module_ctx`.
        logger: logger for diagnostic output.
        debug: whether to add extra diagnostic information about the configured toolchains.
        fail: {type}`function` the fail for failure handling.

    Returns:
        a struct with attributes
    """

    # The toolchain_info structs to register, in the order to register them in.
    # NOTE: The last element is special: it is treated as the default toolchain,
    # so there is special handling to ensure the last entry is the correct one.
    toolchains = []

    # Map of string Major.Minor or Major.Minor.Patch to the toolchain_info struct
    global_toolchain_versions = {}

    ignore_root_user_error = None

    # We store the default toolchain separately to ensure it is the last
    # toolchain added to toolchains.
    # This is a toolchain_info struct.
    default_toolchain = None

    # if the root module does not register any toolchain then the
    # ignore_root_user_error takes its default value: False
    if not mctx.modules[0].tags.toolchain:
        ignore_root_user_error = False

    seen_versions = {}

    # overrides that can be changed by the root module
    overrides = struct(
        kwargs = {},
        minor_mapping = dict(MINOR_MAPPING),
        default = {
            "base_url": DEFAULT_RELEASE_BASE_URL,
            "tool_versions": {
                version: {
                    # Use a dicts straight away so that we could do URL overrides for a
                    # single version.
                    "sha256": dict(item["sha256"]),
                    "strip_prefix": {
                        platform: item["strip_prefix"]
                        for platform in item["sha256"]
                    },
                    "url": {
                        platform: [item["url"]]
                        for platform in item["sha256"]
                    },
                }
                for version, item in TOOL_VERSIONS.items()
            },
        },
    )

    for mod in mctx.modules:
        module_toolchain_versions = []

        requested_toolchains = _process_tag_classes(
            mod,
            seen_versions = seen_versions,
            overrides = overrides,
        )

        for toolchain_attr in requested_toolchains:
            toolchain_version = toolchain_attr.python_version
            toolchain_name = "python_" + toolchain_version.replace(".", "_")

            # Duplicate versions within a module indicate a misconfigured module.
            if toolchain_version in module_toolchain_versions:
                _fail_duplicate_module_toolchain_version(toolchain_version, mod.name)
            module_toolchain_versions.append(toolchain_version)

            if mod.is_root:
                # Only the root module and rules_python are allowed to specify the default
                # toolchain for a couple reasons:
                # * It prevents submodules from specifying different defaults and only
                #   one of them winning.
                # * rules_python needs to set a soft default in case the root module doesn't,
                #   e.g. if the root module doesn't use Python itself.
                # * The root module is allowed to override the rules_python default.
                is_default = toolchain_attr.is_default

                # Also only the root module should be able to decide ignore_root_user_error.
                # Modules being depended upon don't know the final environment, so they aren't
                # in the right position to know or decide what the correct setting is.

                # If an inconsistency in the ignore_root_user_error among multiple toolchains is detected, fail.
                if ignore_root_user_error != None and toolchain_attr.ignore_root_user_error != ignore_root_user_error:
                    fail("Toolchains in the root module must have consistent 'ignore_root_user_error' attributes")

                ignore_root_user_error = toolchain_attr.ignore_root_user_error
            elif mod.name == "rules_python" and not default_toolchain:
                # We don't do the len() check because we want the default that rules_python
                # sets to be clearly visible.
                is_default = toolchain_attr.is_default
            else:
                is_default = False

            if is_default and default_toolchain != None:
                _fail_multiple_default_toolchains(
                    first = default_toolchain.name,
                    second = toolchain_name,
                )

            # Ignore version collisions in the global scope because there isn't
            # much else that can be done. Modules don't know and can't control
            # what other modules do, so the first in the dependency graph wins.
            if toolchain_version in global_toolchain_versions:
                # If the python version is explicitly provided by the root
                # module, they should not be warned for choosing the same
                # version that rules_python provides as default.
                first = global_toolchain_versions[toolchain_version]
                if mod.name != "rules_python" or not first.module.is_root:
                    # The warning can be enabled by setting the verbosity:
                    # env RULES_PYTHON_REPO_DEBUG_VERBOSITY=INFO bazel build //...
                    _warn_duplicate_global_toolchain_version(
                        toolchain_version,
                        first = first,
                        second_toolchain_name = toolchain_name,
                        second_module_name = mod.name,
                        logger = logger,
                    )
                toolchain_info = None
            else:
                toolchain_info = struct(
                    python_version = toolchain_version,
                    name = toolchain_name,
                    module = struct(name = mod.name, is_root = mod.is_root),
                    register_coverage_tool = toolchain_attr.configure_coverage_tool,
                )
                global_toolchain_versions[toolchain_version] = toolchain_info

            if is_default:
                # This toolchain is setting the default, but the actual
                # registration was performed previously, by a different module.
                if toolchain_info == None:
                    default_toolchain = global_toolchain_versions[toolchain_version]

                    # Remove it because later code will add it at the end to
                    # ensure it is last in the list.
                    toolchains.remove(default_toolchain)
                else:
                    default_toolchain = toolchain_info
            elif toolchain_info:
                toolchains.append(toolchain_info)

    overrides.default.setdefault("ignore_root_user_error", ignore_root_user_error)

    # A default toolchain is required so that the non-version-specific rules
    # are able to match a toolchain.
    if default_toolchain == None:
        fail("No default Python toolchain configured. Is rules_python missing `is_default=True`?")
    elif default_toolchain.python_version not in global_toolchain_versions:
        fail('Default version "{python_version}" selected by module ' +
             '"{module_name}", but no toolchain with that version registered'.format(
                 python_version = default_toolchain.python_version,
                 module_name = default_toolchain.module.name,
             ))

    # The last toolchain in the BUILD file is set as the default
    # toolchain. We need the default last.
    toolchains.append(default_toolchain)

    if len(toolchains) > _MAX_NUM_TOOLCHAINS:
        fail("more than {} python versions are not supported".format(_MAX_NUM_TOOLCHAINS))

    return struct(
        default_python_version = default_toolchain.python_version,
        toolchains = [
            struct(
                name = t.name,
                python_version = t.python_version,
                register_coverage_tool = t.register_coverage_tool,
            ) if not debug else struct(
                name = t.name,
                python_version = t.python_version,
                register_coverage_tool = t.register_coverage_tool,
                debug = {
                    "ignore_root_user_error": ignore_root_user_error,
                    "module": t.module,
                } if debug else None,
            )
            for t in toolchains
        ],
        overrides = overrides,
    )

def _python_impl(mctx):
    logger = repo_utils.logger(mctx, "python")

    if mctx.os.environ.get("RULES_PYTHON_BZLMOD_DEBUG", "0") == "1":
        debug_info = {
            "toolchains_registered": [],
        }
    else:
        debug_info = None

    py = parse_mods(mctx = mctx, logger = logger, debug = debug_info != None)

    for toolchain in py.toolchains:
        # Ensure that we pass the full version here.
        full_python_version = full_version(toolchain.python_version, py.overrides.minor_mapping)
        kwargs = {
            "python_version": full_python_version,
            "register_coverage_tool": toolchain.register_coverage_tool,
        }

        # Allow overrides per python version
        kwargs.update(py.overrides.kwargs.get(toolchain.python_version, {}))
        kwargs.update(py.overrides.kwargs.get(full_python_version, {}))
        kwargs.update(py.overrides.default)
        python_register_toolchains(name = toolchain.name, **kwargs)
        if debug_info:
            debug_info["default"] = py.overrides.default
            debug_info["toolchains_registered"].append(dict(
                name = toolchain.name,
                **toolchain.debug
            ))

    # Create the pythons_hub repo for the interpreter meta data and the
    # the various toolchains.
    hub_repo(
        name = "pythons_hub",
        default_python_version = py.default_python_version,
        toolchain_prefixes = [
            render.toolchain_prefix(index, toolchain.name, _TOOLCHAIN_INDEX_PAD_LENGTH)
            for index, toolchain in enumerate(py.toolchains)
        ],
        toolchain_python_versions = [
            full_version(t.python_version, py.overrides.minor_mapping)
            for t in py.toolchains
        ],
        # The last toolchain is the default; it can't have version constraints
        # Despite the implication of the arg name, the values are strs, not bools
        toolchain_set_python_version_constraints = [
            "True" if i != len(py.toolchains) - 1 else "False"
            for i in range(len(py.toolchains))
        ],
        toolchain_user_repository_names = [t.name for t in py.toolchains],
    )

    # This is require in order to support multiple version py_test
    # and py_binary
    multi_toolchain_aliases(
        name = "python_versions",
        python_versions = {
            toolchain.python_version: toolchain.name
            for toolchain in py.toolchains
        },
    )

    if debug_info != None:
        _debug_repo(
            name = "rules_python_bzlmod_debug",
            debug_info = json.encode_indent(debug_info),
        )

    if bazel_features.external_deps.extension_metadata_has_reproducible:
        return mctx.extension_metadata(reproducible = True)
    else:
        return None

def _fail_duplicate_module_toolchain_version(version, module):
    fail(("Duplicate module toolchain version: module '{module}' attempted " +
          "to use version '{version}' multiple times in itself").format(
        version = version,
        module = module,
    ))

def _warn_duplicate_global_toolchain_version(version, first, second_toolchain_name, second_module_name, logger):
    if not logger:
        return

    logger.info(lambda: (
        "Ignoring toolchain '{second_toolchain}' from module '{second_module}': " +
        "Toolchain '{first_toolchain}' from module '{first_module}' " +
        "already registered Python version {version} and has precedence."
    ).format(
        first_toolchain = first.name,
        first_module = first.module.name,
        second_module = second_module_name,
        second_toolchain = second_toolchain_name,
        version = version,
    ))

def _fail_multiple_default_toolchains(first, second):
    fail(("Multiple default toolchains: only one toolchain " +
          "can have is_default=True. First default " +
          "was toolchain '{first}'. Second was '{second}'").format(
        first = first,
        second = second,
    ))

def _process_tag_classes(mod, *, seen_versions, overrides, fail = fail):
    registrations = []

    for tag in mod.tags.toolchain:
        registrations.append(_create_toolchain_attrs_struct(
            tag = tag,
            toolchain_tag_count = len(mod.tags.toolchain),
        ))
        seen_versions[tag.python_version] = True

    if not mod.is_root:
        return registrations

    available_versions = overrides.default["tool_versions"]

    for tag in mod.tags.single_version_override:
        if tag.sha256 or tag.urls:
            if not (tag.sha256 and tag.urls):
                fail("Both `sha256` and `urls` overrides need to be provided together")

            for platform in tag.sha256 or []:
                if platform not in PLATFORMS:
                    fail("The platform must be one of {allowed} but got '{got}'".format(
                        allowed = sorted(PLATFORMS),
                        got = platform,
                    ))

        sha256 = dict(tag.sha256) or available_versions[tag.python_version]["sha256"]
        override = {
            "sha256": sha256,
            "strip_prefix": {
                platform: tag.strip_prefix
                for platform in sha256
            },
            "url": {
                platform: list(tag.urls)
                for platform in tag.sha256
            } or available_versions[tag.python_version]["url"],
        }

        if tag.patches:
            override["patch_strip"] = {
                platform: tag.patch_strip
                for platform in sha256
            }
            override["patches"] = {
                platform: list(tag.patches)
                for platform in sha256
            }

        available_versions[tag.python_version] = {k: v for k, v in override.items() if v}

        if tag.distutils_content:
            overrides.kwargs.setdefault(tag.python_version, {})["distutils_content"] = tag.distutils_content
        if tag.distutils:
            overrides.kwargs.setdefault(tag.python_version, {})["distutils"] = tag.distutils

    for tag in mod.tags.single_version_platform_override:
        if tag.python_version not in available_versions:
            if not tag.urls or not tag.sha256 or not tag.strip_prefix:
                fail("When introducing a new python_version '{}', 'sha256', 'strip_prefix' and 'urls' must be specified".format(tag.python_version))
            available_versions[tag.python_version] = {}

        if tag.coverage_tool:
            available_versions[tag.python_version].setdefault("coverage_tool", {})[tag.platform] = tag.coverage_tool
        if tag.patch_strip:
            available_versions[tag.python_version].setdefault("patch_strip", {})[tag.platform] = tag.patch_strip
        if tag.patches:
            available_versions[tag.python_version].setdefault("patches", {})[tag.platform] = list(tag.patches)
        if tag.sha256:
            available_versions[tag.python_version].setdefault("sha256", {})[tag.platform] = tag.sha256
        if tag.strip_prefix:
            available_versions[tag.python_version].setdefault("strip_prefix", {})[tag.platform] = tag.strip_prefix
        if tag.urls:
            available_versions[tag.python_version].setdefault("url", {})[tag.platform] = tag.urls

    register_all = False
    for tag in mod.tags.override:
        overrides.kwargs["base_url"] = tag.base_url
        if tag.available_python_versions:
            all_versions = dict(available_versions)
            available_versions.clear()
            available_versions.update({
                v: all_versions[v] if v in all_versions else fail("unknown version '{}', known versions are: {}".format(
                    v,
                    sorted(all_versions),
                ))
                for v in tag.available_python_versions
            })

        if tag.register_all_versions and mod.name != "rules_python":
            fail("This override can only be used by 'rules_python'")
        elif tag.register_all_versions:
            register_all = True

        if tag.minor_mapping:
            for minor_version, full_version in tag.minor_mapping.items():
                parsed = semver(minor_version)
                if parsed.patch or parsed.build:
                    fail("Expected the key to be of `X.Y` format but got `{}`".format(minor_version))
                parsed = semver(full_version)
                if not parsed.patch:
                    fail("Expected the value to at least be of `X.Y.Z` format but got `{}`".format(minor_version))

            overrides.minor_mapping.clear()
            overrides.minor_mapping.update(tag.minor_mapping)

        for key in sorted(AUTH_ATTRS) + ["ignore_root_user_error"]:
            if getattr(tag, key, None):
                overrides.default[key] = getattr(tag, key)

        break

    if register_all:
        # FIXME @aignas 2024-08-30: this is technically not correct
        registrations.extend([
            _create_toolchain_attrs_struct(python_version = v)
            for v in available_versions.keys()
            if v not in seen_versions
        ])

    return registrations

def _create_toolchain_attrs_struct(*, tag = None, python_version = None, toolchain_tag_count = None):
    if tag and python_version:
        fail("Only one of tag and python version can be specified")
    if tag:
        # A single toolchain is treated as the default because it's unambiguous.
        is_default = tag.is_default or toolchain_tag_count == 1
    else:
        is_default = False

    return struct(
        is_default = is_default,
        python_version = python_version if python_version else tag.python_version,
        configure_coverage_tool = getattr(tag, "configure_coverage_tool", False),
        ignore_root_user_error = getattr(tag, "ignore_root_user_error", False),
    )

def _get_bazel_version_specific_kwargs():
    kwargs = {}

    if IS_BAZEL_6_4_OR_HIGHER:
        kwargs["environ"] = ["RULES_PYTHON_BZLMOD_DEBUG"]

    return kwargs

_toolchain = tag_class(
    doc = """Tag class used to register Python toolchains.
Use this tag class to register one or more Python toolchains. This class
is also potentially called by sub modules. The following covers different
business rules and use cases.

:::{topic} Toolchains in the Root Module

This class registers all toolchains in the root module.
:::

:::{topic} Toolchains in Sub Modules

It will create a toolchain that is in a sub module, if the toolchain
of the same name does not exist in the root module.  The extension stops name
clashing between toolchains in the root module and toolchains in sub modules.
You cannot configure more than one toolchain as the default toolchain.
:::

:::{topic} Toolchain set as the default version

This extension will not create a toolchain that exists in a sub module,
if the sub module toolchain is marked as the default version. If you have
more than one toolchain in your root module, you need to set one of the
toolchains as the default version.  If there is only one toolchain it
is set as the default toolchain.
:::

:::{topic} Toolchain repository name

A toolchain's repository name uses the format `python_{major}_{minor}`, e.g.
`python_3_10`. The `major` and `minor` components are
`major` and `minor` are the Python version from the `python_version` attribute.

If a toolchain is registered in `X.Y.Z`, then similarly the toolchain name will
be `python_{major}_{minor}_{patch}`, e.g. `python_3_10_19`.
:::

:::{topic} Toolchain detection
The definition of the first toolchain wins, which means that the root module
can override settings for any python toolchain available. This relies on the
documented module traversal from the {obj}`module_ctx.modules`.
:::

:::{tip}
In order to use a different name than the above, you can use the following `MODULE.bazel`
syntax:
```starlark
python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(
    is_default = True,
    python_version = "3.11",
)

use_repo(python, my_python_name = "python_3_11")
```

Then the python interpreter will be available as `my_python_name`.
:::
""",
    attrs = {
        "configure_coverage_tool": attr.bool(
            mandatory = False,
            doc = "Whether or not to configure the default coverage tool provided by `rules_python` for the compatible toolchains.",
        ),
        "ignore_root_user_error": attr.bool(
            default = False,
            doc = """\
If `False`, the Python runtime installation will be made read only. This improves
the ability for Bazel to cache it, but prevents the interpreter from creating
`.pyc` files for the standard library dynamically at runtime as they are loaded.

If `True`, the Python runtime installation is read-write. This allows the
interpreter to create `.pyc` files for the standard library, but, because they are
created as needed, it adversely affects Bazel's ability to cache the runtime and
can result in spurious build failures.
""",
            mandatory = False,
        ),
        "is_default": attr.bool(
            mandatory = False,
            doc = "Whether the toolchain is the default version",
        ),
        "python_version": attr.string(
            mandatory = True,
            doc = """\
The Python version, in `major.minor` or `major.minor.patch` format, e.g
`3.12` (or `3.12.3`), to create a toolchain for.
""",
        ),
    },
)

_override = tag_class(
    doc = """Tag class used to override defaults and behaviour of the module extension.

:::{versionadded} 0.36.0
:::
""",
    attrs = dict(
        {
            "available_python_versions": attr.string_list(
                mandatory = False,
                doc = "The list of available python tool versions to use. Must be in `X.Y.Z` format.",
            ),
            "base_url": attr.string(
                mandatory = False,
                doc = "The base URL to be used when downloading toolchains.",
                default = DEFAULT_RELEASE_BASE_URL,
            ),
            "ignore_root_user_error": attr.bool(
                default = False,
                doc = """\
If `False`, the Python runtime installation will be made read only. This improves
the ability for Bazel to cache it, but prevents the interpreter from creating
`.pyc` files for the standard library dynamically at runtime as they are loaded.

If `True`, the Python runtime installation is read-write. This allows the
interpreter to create `.pyc` files for the standard library, but, because they are
created as needed, it adversely affects Bazel's ability to cache the runtime and
can result in spurious build failures.
""",
                mandatory = False,
            ),
            "minor_mapping": attr.string_dict(
                mandatory = False,
                doc = "The mapping between `X.Y` to `X.Y.Z` versions to be used when setting up toolchains.",
                default = {},
            ),
            "register_all_versions": attr.bool(default = False, doc = "Add all versions"),
        },
        **AUTH_ATTRS
    ),
)

_single_version_override = tag_class(
    doc = """Override single python version URLs and patches for all platforms.

:::{note}
This will replace any existing configuration for the given python version.
:::

:::{tip}
If you would like to modify the configuration for a specific `(version,
platform)`, please use the {obj}`single_version_platform_override` tag
class.
:::

:::{versionadded} 0.36.0
:::
""",
    attrs = {
        # NOTE @aignas 2024-09-01: all of the attributes except for `version`
        # can be part of the `python.toolchain` call. That would make it more
        # ergonomic to define new toolchains and to override values for old
        # toolchains. The same semantics of the `first one wins` would apply,
        # so technically there is no need for any overrides?
        #
        # Although these attributes would override the code that is used by the
        # code in non-root modules, so technically this could be thought as
        # being overridden.
        #
        # rules_go has a single download call:
        # https://github.com/bazelbuild/rules_go/blob/master/go/private/extensions.bzl#L38
        #
        # However, we need to understand how to accommodate the fact that
        # {attr}`single_version_override.version` only allows patch versions.
        "distutils": attr.label(
            allow_single_file = True,
            doc = "A distutils.cfg file to be included in the Python installation. " +
                  "Either {attr}`distutils` or {attr}`distutils_content` can be specified, but not both.",
            mandatory = False,
        ),
        "distutils_content": attr.string(
            doc = "A distutils.cfg file content to be included in the Python installation. " +
                  "Either {attr}`distutils` or {attr}`distutils_content` can be specified, but not both.",
            mandatory = False,
        ),
        "patch_strip": attr.int(
            mandatory = False,
            doc = "Same as the --strip argument of Unix patch.",
            default = 0,
        ),
        "patches": attr.label_list(
            mandatory = False,
            doc = "A list of labels pointing to patch files to apply for the interpreter repository. They are applied in the list order and are applied before any platform-specific patches are applied.",
        ),
        "python_version": attr.string(
            mandatory = True,
            doc = "The python version to override URLs for. Must be in `X.Y.Z` format.",
        ),
        "sha256": attr.string_dict(
            mandatory = False,
            doc = "The python platform to sha256 dict. See {attr}`python.single_version_platform_override.platform` for allowed key values.",
        ),
        "strip_prefix": attr.string(
            mandatory = False,
            doc = "The 'strip_prefix' for the archive, defaults to 'python'.",
            default = "python",
        ),
        "urls": attr.string_list(
            mandatory = False,
            doc = "The URL template to fetch releases for this Python version. See {attr}`python.single_version_platform_override.urls` for documentation.",
        ),
    },
)

_single_version_platform_override = tag_class(
    doc = """Override single python version for a single existing platform.

If the `(version, platform)` is new, we will add it to the existing versions and will
use the same `url` template.

:::{tip}
If you would like to add or remove platforms to a single python version toolchain
configuration, please use {obj}`single_version_override`.
:::

:::{versionadded} 0.36.0
:::
""",
    attrs = {
        "coverage_tool": attr.label(
            doc = """\
The coverage tool to be used for a particular Python interpreter. This can override
`rules_python` defaults.
""",
        ),
        "patch_strip": attr.int(
            mandatory = False,
            doc = "Same as the --strip argument of Unix patch.",
            default = 0,
        ),
        "patches": attr.label_list(
            mandatory = False,
            doc = "A list of labels pointing to patch files to apply for the interpreter repository. They are applied in the list order and are applied after the common patches are applied.",
        ),
        "platform": attr.string(
            mandatory = True,
            values = PLATFORMS.keys(),
            doc = "The platform to override the values for, must be one of:\n{}.".format("\n".join(sorted(["* `{}`".format(p) for p in PLATFORMS]))),
        ),
        "python_version": attr.string(
            mandatory = True,
            doc = "The python version to override URLs for. Must be in `X.Y.Z` format.",
        ),
        "sha256": attr.string(
            mandatory = False,
            doc = "The sha256 for the archive",
        ),
        "strip_prefix": attr.string(
            mandatory = False,
            doc = "The 'strip_prefix' for the archive, defaults to 'python'.",
            default = "python",
        ),
        "urls": attr.string_list(
            mandatory = False,
            doc = "The URL template to fetch releases for this Python version. If the URL template results in a relative fragment, default base URL is going to be used. Occurrences of `{python_version}`, `{platform}` and `{build}` will be interpolated based on the contents in the override and the known {attr}`platform` values.",
        ),
    },
)

python = module_extension(
    doc = """Bzlmod extension that is used to register Python toolchains.
""",
    implementation = _python_impl,
    tag_classes = {
        "override": _override,
        "single_version_override": _single_version_override,
        "single_version_platform_override": _single_version_platform_override,
        "toolchain": _toolchain,
    },
    **_get_bazel_version_specific_kwargs()
)

_DEBUG_BUILD_CONTENT = """
package(
    default_visibility = ["//visibility:public"],
)
exports_files(["debug_info.json"])
"""

def _debug_repo_impl(repo_ctx):
    repo_ctx.file("BUILD.bazel", _DEBUG_BUILD_CONTENT)
    repo_ctx.file("debug_info.json", repo_ctx.attr.debug_info)

_debug_repo = repository_rule(
    implementation = _debug_repo_impl,
    attrs = {
        "debug_info": attr.string(),
    },
)
