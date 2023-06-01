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

load("//python:repositories.bzl", "python_register_toolchains")
load("//python/extensions/private:pythons_hub.bzl", "hub_repo")
load("//python/private:toolchains_repo.bzl", "multi_toolchain_aliases")

# This limit can be increased essentially arbitrarily, but doing so will cause a rebuild of all
# targets using any of these toolchains due to the changed repository name.
_MAX_NUM_TOOLCHAINS = 9999
_TOOLCHAIN_INDEX_PAD_LENGTH = len(str(_MAX_NUM_TOOLCHAINS))

def _toolchain_prefix(index, name):
    """Prefixes the given name with the index, padded with zeros to ensure lexicographic sorting.

    Examples:
      _toolchain_prefix(   2, "foo") == "_0002_foo_"
      _toolchain_prefix(2000, "foo") == "_2000_foo_"
    """
    return "_{}_{}_".format(_left_pad_zero(index, _TOOLCHAIN_INDEX_PAD_LENGTH), name)

def _left_pad_zero(index, length):
    if index < 0:
        fail("index must be non-negative")
    return ("0" * length + str(index))[-length:]

# Printing a warning msg not debugging, so we have to disable
# the buildifier check.
# buildifier: disable=print
def _print_warn(msg):
    print("WARNING:", msg)

def _python_register_toolchains(toolchain_attr, version_constraint):
    """Calls python_register_toolchains and returns a struct used to collect the toolchains.
    """
    python_register_toolchains(
        name = toolchain_attr.name,
        python_version = toolchain_attr.python_version,
        register_coverage_tool = toolchain_attr.configure_coverage_tool,
        ignore_root_user_error = toolchain_attr.ignore_root_user_error,
        set_python_version_constraint = version_constraint,
    )
    return struct(
        python_version = toolchain_attr.python_version,
        set_python_version_constraint = str(version_constraint),
        name = toolchain_attr.name,
    )

def _python_impl(module_ctx):
    # Use to store all of the toolchains
    toolchains = []

    # Used to check if toolchains already exist
    toolchain_names = []

    # Used to store toolchains that are in sub modules.
    sub_toolchains_map = {}
    default_toolchain = None
    python_versions = {}

    for mod in module_ctx.modules:
        for toolchain_attr in mod.tags.toolchain:
            # If we are in the root module we always register the toolchain.
            # We wait to register the default toolchain till the end.
            if mod.is_root:
                if toolchain_attr.name in toolchain_names:
                    fail("""We found more than one toolchain that is named: {}.
All toolchains must have an unique name.""".format(toolchain_attr.name))

                toolchain_names.append(toolchain_attr.name)

                # If we have the default version or we only have one toolchain
                # in the root module we set the toolchain as the default toolchain.
                if toolchain_attr.is_default or len(mod.tags.toolchain) == 1:
                    # We have already found one default toolchain, and we can
                    # only have one.
                    if default_toolchain != None:
                        fail("""We found more than one toolchain that is marked 
as the default version.  Only set one toolchain with is_default set as 
True. The toolchain is named: {}""".format(toolchain_attr.name))

                    # We store the default toolchain to have it
                    # as the last toolchain added to toolchains
                    default_toolchain = _python_register_toolchains(
                        toolchain_attr,
                        version_constraint = False,
                    )
                    python_versions[toolchain_attr.python_version] = toolchain_attr.name
                    continue

                toolchains.append(
                    _python_register_toolchains(
                        toolchain_attr,
                        version_constraint = True,
                    ),
                )
                python_versions[toolchain_attr.python_version] = toolchain_attr.name
            else:
                # We add the toolchain to a map, and we later create the
                # toolchain if the root module does not have a toolchain with
                # the same name.  We have to loop through all of the modules to
                # ensure that we get a full list of the root toolchains.
                sub_toolchains_map[toolchain_attr.name] = toolchain_attr

    # We did not find a default toolchain so we fail.
    if default_toolchain == None:
        fail("""Unable to find a default toolchain in the root module.  
Please define a toolchain that has is_version set to True.""")

    # Create the toolchains in the submodule(s).
    for name, toolchain_attr in sub_toolchains_map.items():
        # We cannot have a toolchain in a sub module that has the same name of
        # a toolchain in the root module. This will cause name clashing.
        if name in toolchain_names:
            _print_warn("""Not creating the toolchain from sub module, with the name {}. The root
 module has a toolchain of the same name.""".format(toolchain_attr.name))
            continue
        toolchain_names.append(name)
        toolchains.append(
            _python_register_toolchains(
                toolchain_attr,
                version_constraint = True,
            ),
        )
        python_versions[toolchain_attr.python_version] = toolchain_attr.name

    # The last toolchain in the BUILD file is set as the default
    # toolchain. We need the default last.
    toolchains.append(default_toolchain)

    if len(toolchains) > _MAX_NUM_TOOLCHAINS:
        fail("more than {} python versions are not supported".format(_MAX_NUM_TOOLCHAINS))

    # Create the pythons_hub repo for the interpreter meta data and the
    # the various toolchains.
    hub_repo(
        name = "pythons_hub",
        toolchain_prefixes = [
            _toolchain_prefix(index, toolchain.name)
            for index, toolchain in enumerate(toolchains)
        ],
        toolchain_python_versions = [t.python_version for t in toolchains],
        toolchain_set_python_version_constraints = [t.set_python_version_constraint for t in toolchains],
        toolchain_user_repository_names = [t.name for t in toolchains],
    )

    # This is require in order to support multiple version py_test
    # and py_binary
    multi_toolchain_aliases(
        name = "python_aliases",
        python_versions = python_versions,
    )

python = module_extension(
    doc = """Bzlmod extension that is used to register Python toolchains.
""",
    implementation = _python_impl,
    tag_classes = {
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
""",
            attrs = {
                "configure_coverage_tool": attr.bool(
                    mandatory = False,
                    doc = "Whether or not to configure the default coverage tool for the toolchains.",
                ),
                "ignore_root_user_error": attr.bool(
                    default = False,
                    doc = "Whether the check for root should be ignored or not. This causes cache misses with .pyc files.",
                    mandatory = False,
                ),
                "is_default": attr.bool(
                    mandatory = False,
                    doc = "Whether the toolchain is the default version",
                ),
                "name": attr.string(
                    mandatory = True,
                    doc = "Name of the toolchain",
                ),
                "python_version": attr.string(
                    mandatory = True,
                    doc = "The Python version that we are creating the toolchain for.",
                ),
            },
        ),
    },
)
