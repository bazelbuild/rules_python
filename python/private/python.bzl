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

"Python toolchain module extensions for use with bzlmod"

load("@bazel_features//:features.bzl", "bazel_features")
load("//python:repositories.bzl", "python_register_toolchains")
load("//python:versions.bzl", "MINOR_MAPPING", "TOOL_VERSIONS")
load(":full_version.bzl", "full_version")
load(":pythons_hub.bzl", "hub_repo")
load(":repo_utils.bzl", "repo_utils")
load(":text_util.bzl", "render")
load(":toolchains_repo.bzl", "multi_toolchain_aliases")
load(":util.bzl", "IS_BAZEL_6_4_OR_HIGHER")

# This limit can be increased essentially arbitrarily, but doing so will cause a rebuild of all
# targets using any of these toolchains due to the changed repository name.
_MAX_NUM_TOOLCHAINS = 9999
_TOOLCHAIN_INDEX_PAD_LENGTH = len(str(_MAX_NUM_TOOLCHAINS))

def parse_modules(module_ctx):
    """Parse the modules and return a struct for registrations.

    Args:
        module_ctx: {type}`module_ctx` module context.

    Returns:
        A struct with the following attributes:
            * `toolchains`: The list of toolchains to register. The last
              element is special and is treated as the default toolchain.
            * `defaults`: The default `kwargs` passed to
              {bzl:obj}`python_register_toolchains`.
            * `debug_info`: {type}`None | dict` extra information to be passed
              to the debug repo.
    """
    if module_ctx.os.environ.get("RULES_PYTHON_BZLMOD_DEBUG", "0") == "1":
        debug_info = {
            "toolchains_registered": [],
        }
    else:
        debug_info = None

    # The toolchain_info structs to register, in the order to register them in.
    # NOTE: The last element is special: it is treated as the default toolchain,
    # so there is special handling to ensure the last entry is the correct one.
    toolchains = []

    # We store the default toolchain separately to ensure it is the last
    # toolchain added to toolchains.
    # This is a toolchain_info struct.
    default_toolchain = None

    # Map of version string to the toolchain_info struct
    global_toolchain_versions = {}

    ignore_root_user_error = None

    logger = repo_utils.logger(module_ctx, "python")

    # if the root module does not register any toolchain then the
    # ignore_root_user_error takes its default value: False
    if not module_ctx.modules[0].tags.toolchain:
        ignore_root_user_error = False

    for mod in module_ctx.modules:
        module_toolchain_versions = []

        toolchain_attr_structs = _create_toolchain_attr_structs(mod)

        for toolchain_attr in toolchain_attr_structs:
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
                    python_version = toolchain_attr.python_version,
                    name = toolchain_name,
                    register_coverage_tool = toolchain_attr.configure_coverage_tool,
                    module = struct(name = mod.name, is_root = mod.is_root),
                )
                global_toolchain_versions[toolchain_version] = toolchain_info
                if debug_info:
                    debug_info["toolchains_registered"].append({
                        "ignore_root_user_error": ignore_root_user_error,
                        "name": toolchain_name,
                    })

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
        debug_info = debug_info,
        default_python_version = toolchains[-1].python_version,
        defaults = {
            "ignore_root_user_error": ignore_root_user_error,
        },
        toolchains = [
            struct(
                python_version = t.python_version,
                name = t.name,
                register_coverage_tool = t.register_coverage_tool,
            )
            for t in toolchains
        ],
    )

def _python_impl(module_ctx):
    py = parse_modules(module_ctx)

    for toolchain_info in py.toolchains:
        python_register_toolchains(
            name = toolchain_info.name,
            python_version = toolchain_info.python_version,
            register_coverage_tool = toolchain_info.register_coverage_tool,
            minor_mapping = MINOR_MAPPING,
            **py.defaults
        )

    # Create the pythons_hub repo for the interpreter meta data and the
    # the various toolchains.
    hub_repo(
        name = "pythons_hub",
        # Last toolchain is default
        default_python_version = py.default_python_version,
        toolchain_prefixes = [
            render.toolchain_prefix(index, toolchain.name, _TOOLCHAIN_INDEX_PAD_LENGTH)
            for index, toolchain in enumerate(py.toolchains)
        ],
        toolchain_python_versions = [
            full_version(version = t.python_version, minor_mapping = MINOR_MAPPING)
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

    if py.debug_info != None:
        _debug_repo(
            name = "rules_python_bzlmod_debug",
            debug_info = json.encode_indent(py.debug_info),
        )

    if bazel_features.external_deps.extension_metadata_has_reproducible:
        return module_ctx.extension_metadata(reproducible = True)
    else:
        return None

def _fail_duplicate_module_toolchain_version(version, module):
    fail(("Duplicate module toolchain version: module '{module}' attempted " +
          "to use version '{version}' multiple times in itself").format(
        version = version,
        module = module,
    ))

def _warn_duplicate_global_toolchain_version(version, first, second_toolchain_name, second_module_name, logger):
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

def _create_toolchain_attr_structs(mod):
    arg_structs = []
    seen_versions = {}
    for tag in mod.tags.toolchain:
        arg_structs.append(_create_toolchain_attrs_struct(tag = tag, toolchain_tag_count = len(mod.tags.toolchain)))
        seen_versions[tag.python_version] = True

    if mod.is_root:
        register_all = False
        for tag in mod.tags.rules_python_private_testing:
            if tag.register_all_versions:
                register_all = True
                break
        if register_all:
            arg_structs.extend([
                _create_toolchain_attrs_struct(python_version = v)
                for v in TOOL_VERSIONS.keys()
                if v not in seen_versions
            ])
    return arg_structs

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
        coverage_rc = getattr(tag, "coverage_rc", None),
    )

def _get_bazel_version_specific_kwargs():
    kwargs = {}

    if IS_BAZEL_6_4_OR_HIGHER:
        kwargs["environ"] = ["RULES_PYTHON_BZLMOD_DEBUG"]

    return kwargs

python = module_extension(
    doc = """Bzlmod extension that is used to register Python toolchains.
""",
    implementation = _python_impl,
    tag_classes = {
        "rules_python_private_testing": tag_class(
            attrs = {
                "register_all_versions": attr.bool(default = False),
            },
        ),
        "toolchain": tag_class(
            doc = """Tag class used to register Python toolchains.
Use this tag class to register one or more Python toolchains. This class
is also potentially called by sub modules. The following covers different
business rules and use cases.

Toolchains in the Root Module

This class registers all toolchains in the root module.

Toolchains in Sub Modules

It will create a toolchain that is in a sub module, if the toolchain
of the same name does not exist in the root module.  The extension stops name
clashing between toolchains in the root module and toolchains in sub modules.
You cannot configure more than one toolchain as the default toolchain.

Toolchain set as the default version

This extension will not create a toolchain that exists in a sub module,
if the sub module toolchain is marked as the default version. If you have
more than one toolchain in your root module, you need to set one of the
toolchains as the default version.  If there is only one toolchain it
is set as the default toolchain.

Toolchain repository name

A toolchain's repository name uses the format `python_{major}_{minor}`, e.g.
`python_3_10`. The `major` and `minor` components are
`major` and `minor` are the Python version from the `python_version` attribute.
""",
            attrs = {
                "configure_coverage_tool": attr.bool(
                    mandatory = False,
                    doc = "Whether or not to configure the default coverage tool for the toolchains.",
                ),
                "coverage_rc": attr.label(
                    mandatory = False,
                    doc = "The coverage configuration file to use for the toolchains.",
                ),
                "ignore_root_user_error": attr.bool(
                    default = False,
                    doc = """\
If False, the Python runtime installation will be made read only. This improves
the ability for Bazel to cache it, but prevents the interpreter from creating
pyc files for the standard library dynamically at runtime as they are loaded.

If True, the Python runtime installation is read-write. This allows the
interpreter to create pyc files for the standard library, but, because they are
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
                    doc = "The Python version, in `major.minor` format, e.g " +
                          "'3.12', to create a toolchain for. Patch level " +
                          "granularity (e.g. '3.12.1') is not supported.",
                ),
            },
        ),
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
