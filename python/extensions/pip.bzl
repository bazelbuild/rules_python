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

"pip module extension for use with bzlmod"

load("@pythons_hub//:interpreters.bzl", "DEFAULT_PYTHON_VERSION", "INTERPRETER_LABELS")
load("@rules_python//python:pip.bzl", "whl_library_alias")
load(
    "@rules_python//python/pip_install:pip_repository.bzl",
    "locked_requirements_label",
    "pip_hub_repository_bzlmod",
    "pip_repository_attrs",
    "pip_repository_bzlmod",
    "use_isolated",
    "whl_library",
)
load("@rules_python//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")

def _whl_mods_impl(mctx):
    """Implmentation of a class tag that creates JSON files used to modify the creation of different wheels.
"""
    whl_mods_dict = {}
    for mod in mctx.modules:
        for whl_mod_attr in mod.tags.whl_mods:
            if whl_mod_attr.hub_name not in whl_mods_dict.keys():
                whl_mods_dict[whl_mod_attr.hub_name] = {whl_mod_attr.whl_name: whl_mod_attr}
            elif whl_mod_attr.whl_name in whl_mods_dict[whl_mod_attr.hub_name].keys():
                # We cannot have the same wheel name in the same hub, as we
                # will create the same JSON file name.
                fail("""\
Found same whl_name '{}' in the same hub '{}', please use a different hub_name.""".format(
                    whl_mod_attr.whl_name,
                    whl_mod_attr.hub_name,
                ))
            else:
                whl_mods_dict[whl_mod_attr.hub_name][whl_mod_attr.whl_name] = whl_mod_attr

    for hub_name, whl_maps in whl_mods_dict.items():
        whl_mods = {}

        # create a struct that we can pass to the _whl_mods_repo rule
        # to create the different JSON files.
        for whl_name, mods in whl_maps.items():
            build_content = mods.additive_build_content
            if mods.additive_build_content_file != None and mods.additive_build_content != "":
                fail("""\
You cannot use both the additive_build_content and additive_build_content_file arguments at the same time.
""")
            elif mods.additive_build_content_file != None:
                build_content = mctx.read(mods.additive_build_content_file)

            whl_mods[whl_name] = json.encode(struct(
                additive_build_content = build_content,
                copy_files = mods.copy_files,
                copy_executables = mods.copy_executables,
                data = mods.data,
                data_exclude_glob = mods.data_exclude_glob,
                srcs_exclude_glob = mods.srcs_exclude_glob,
            ))

        _whl_mods_repo(
            name = hub_name,
            whl_mods = whl_mods,
        )

def _create_pip(module_ctx, pip_attr, whl_map):
    python_interpreter_target = pip_attr.python_interpreter_target

    # if we do not have the python_interpreter set in the attributes
    # we programtically find it.
    if python_interpreter_target == None:
        python_name = "python_{}".format(pip_attr.python_version.replace(".", "_"))
        if python_name not in INTERPRETER_LABELS.keys():
            fail("""
Unable to find '{}' in the list of interpreters please update your pip.parse call with the correct python name
""".format(pip_attr.python_name))

        python_interpreter_target = INTERPRETER_LABELS[python_name]

    hub_name = pip_attr.hub_name
    pip_name = hub_name + "_{}".format(pip_attr.python_version.replace(".", ""))
    requrements_lock = locked_requirements_label(module_ctx, pip_attr)

    # Parse the requirements file directly in starlark to get the information
    # needed for the whl_libary declarations below. This is needed to contain
    # the pip_repository logic to a single module extension.
    requirements_lock_content = module_ctx.read(requrements_lock)
    parse_result = parse_requirements(requirements_lock_content)
    requirements = parse_result.requirements
    extra_pip_args = pip_attr.extra_pip_args + parse_result.options

    # Create the repository where users load the `requirement` macro. Under bzlmod
    # this does not create the install_deps() macro.
    # TODO: we may not need this repository once we have entry points
    # supported. For now a user can access this repository and use
    # the entrypoint functionality.
    pip_repository_bzlmod(
        name = pip_name,
        repo_name = pip_name,
        requirements_lock = pip_attr.requirements_lock,
    )
    if hub_name not in whl_map:
        whl_map[hub_name] = {}

    whl_modifications = {}
    if pip_attr.whl_modifications != None:
        for mod, whl_name in pip_attr.whl_modifications.items():
            whl_modifications[whl_name] = mod

    # Create a new wheel library for each of the different whls
    for whl_name, requirement_line in requirements:
        # We are not using the "sanitized name" because the user
        # would need to guess what name we modified the whl name
        # to.
        annotation = whl_modifications.get(whl_name)
        whl_name = _sanitize_name(whl_name)
        whl_library(
            name = "%s_%s" % (pip_name, whl_name),
            requirement = requirement_line,
            repo = pip_name,
            repo_prefix = pip_name + "_",
            annotation = annotation,
            python_interpreter = pip_attr.python_interpreter,
            python_interpreter_target = python_interpreter_target,
            quiet = pip_attr.quiet,
            timeout = pip_attr.timeout,
            isolated = use_isolated(module_ctx, pip_attr),
            extra_pip_args = extra_pip_args,
            download_only = pip_attr.download_only,
            pip_data_exclude = pip_attr.pip_data_exclude,
            enable_implicit_namespace_pkgs = pip_attr.enable_implicit_namespace_pkgs,
            environment = pip_attr.environment,
        )

        if whl_name not in whl_map[hub_name]:
            whl_map[hub_name][whl_name] = {}

        whl_map[hub_name][whl_name][pip_attr.python_version] = pip_name + "_"

def _pip_impl(module_ctx):
    """Implmentation of a class tag that creates the pip hub(s) and corresponding pip spoke, alias and whl repositories.

    This implmentation iterates through all of the "pip.parse" calls and creates
    different pip hubs repositories based on the "hub_name".  Each of the
    pip calls create spoke repos that uses a specific Python interpreter.

    In a MODULES.bazel file we have:

    pip.parse(
        hub_name = "pip",
        python_version = 3.9,
        requirements_lock = "//:requirements_lock_3_9.txt",
        requirements_windows = "//:requirements_windows_3_9.txt",
    )
    pip.parse(
        hub_name = "pip",
        python_version = 3.10,
        requirements_lock = "//:requirements_lock_3_10.txt",
        requirements_windows = "//:requirements_windows_3_10.txt",
    )

    For instance we have a hub with the name of "pip".
    A repository named the following is created. It is actually called last when
    all of the pip spokes are collected.

    - @@rules_python~override~pip~pip

    As show in the example code above we have the following.
    Two different pip.parse statements exist in MODULE.bazel provide the hub_name "pip".
    These definitions create two different pip spoke repositories that are
    related to the hub "pip".
    One spoke uses Python 3.9 and the other uses Python 3.10. This code automatically
    determines the Python version and the interpreter.
    Both of these pip spokes contain requirements files that includes websocket
    and its dependencies.

    Two different repositories are created for the two spokes:

    - @@rules_python~override~pip~pip_39
    - @@rules_python~override~pip~pip_310

    The different spoke names are a combination of the hub_name and the Python version.
    In the future we may remove this repository, but we do not support entry points.
    yet, and that functionality exists in these repos.

    We also need repositories for the wheels that the different pip spokes contain.
    For each Python version a different wheel repository is created. In our example
    each pip spoke had a requirments file that contained websockets. We
    then create two different wheel repositories that are named the following.

    - @@rules_python~override~pip~pip_39_websockets
    - @@rules_python~override~pip~pip_310_websockets

    And if the wheel has any other dependies subsequest wheels are created in the same fashion.

    We also create a repository for the wheel alias.  We want to just use the syntax
    'requirement("websockets")' we need to have an alias repository that is named:

    - @@rules_python~override~pip~pip_websockets

    This repository contains alias statements for the different wheel components (pkg, data, etc).
    Each of those aliases has a select that resolves to a spoke repository depending on
    the Python version.

    Also we may have more than one hub as defined in a MODULES.bazel file.  So we could have multiple
    hubs pointing to various different pip spokes.

    Some other business rules notes.  A hub can only have one spoke per Python version.  We cannot
    have a hub named "pip" that has two spokes that use the Python 3.9 interpreter.  Second
    we cannot have the same hub name used in submodules.  The hub name has to be globally
    unique.

    This implementation reuses elements of non-bzlmod code and also reuses the first implementation
    of pip bzlmod, but adds the capability to have multiple pip.parse calls.

    This implmentation also handles the creation of whl_modification JSON files that are used
    during the creation of wheel libraries.  These JSON files used via the annotations argument
    when calling wheel_installer.py.

    Args:
        module_ctx: module contents

    """

    # Build all of the wheel modifications if the tag class is called.
    _whl_mods_impl(module_ctx)

    # Used to track all the different pip hubs and the spoke pip Python
    # versions.
    pip_hub_map = {}

    # Keeps track of all the hub's whl repos across the different versions.
    # dict[hub, dict[whl, dict[version, str pip]]]
    # Where hub, whl, and pip are the repo names
    hub_whl_map = {}

    for mod in module_ctx.modules:
        for pip_attr in mod.tags.parse:
            if pip_attr.hub_name in pip_hub_map:
                # We cannot have two hubs with the same name in different
                # modules.
                if pip_hub_map[pip_attr.hub_name].module_name != mod.name:
                    fail("""Unable to create pip with the hub_name '{}', same hub name 
                        in a different module found.""".format(pip_attr.hub_name))

                if pip_attr.python_version in pip_hub_map[pip_attr.hub_name].python_versions:
                    fail(
                        """Unable to create pip with the hub_name '{}', same hub name 
                        using the same Python repo name '{}' found in module '{}'.""".format(
                            pip_attr.hub_name,
                            pip_attr.python_version,
                            mod.name,
                        ),
                    )
                else:
                    pip_hub_map[pip_attr.hub_name].python_versions.append(pip_attr.python_version)
            else:
                pip_hub_map[pip_attr.hub_name] = struct(
                    module_name = mod.name,
                    python_versions = [pip_attr.python_version],
                )

            _create_pip(module_ctx, pip_attr, hub_whl_map)

    for hub_name, whl_map in hub_whl_map.items():
        for whl_name, version_map in whl_map.items():
            if DEFAULT_PYTHON_VERSION not in version_map:
                fail(
                    """
Unable to find the default python version in the version map, please update your requirements files
to include Python '{}'.
""".format(DEFAULT_PYTHON_VERSION),
                )

            # Create the alias repositories which contains different select
            # statements  These select statements point to the different pip
            # whls that are based on a specific version of Python.
            whl_library_alias(
                name = hub_name + "_" + whl_name,
                wheel_name = whl_name,
                default_version = DEFAULT_PYTHON_VERSION,
                version_map = version_map,
            )

        # Create the hub repository for pip.
        pip_hub_repository_bzlmod(
            name = hub_name,
            repo_name = hub_name,
            whl_library_alias_names = whl_map.keys(),
        )

# Keep in sync with python/pip_install/tools/bazel.py
def _sanitize_name(name):
    return name.replace("-", "_").replace(".", "_").lower()

def _pip_parse_ext_attrs():
    attrs = dict({
        "hub_name": attr.string(
            mandatory = True,
            doc = """
The unique hub name.  Mulitple pip.parse calls that contain the same hub name, 
create spokes for specific Python versions.                                
""",
        ),
        "python_version": attr.string(
            mandatory = True,
            doc = """
The Python version for the pip spoke. 
""",
        ),
        "whl_modifications": attr.label_keyed_string_dict(
            mandatory = False,
            doc = """\
A dict of labels and wheel names that is typically generated by the whl_modifications
extension.
""",
        ),
    }, **pip_repository_attrs)

    # Like the pip_repository rule, we end up setting this manually so
    # don't allow users to override it.
    attrs.pop("repo_prefix")

    # incompatible_generate_aliases is always True in bzlmod
    attrs.pop("incompatible_generate_aliases")

    return attrs

def _mod_tag_attrs():
    attrs = {
        "additive_build_content": attr.string(
            doc = "(str, optional): Raw text to add to the generated `BUILD` file of a package.",
        ),
        "additive_build_content_file": attr.label(
            doc = """\
(label, optional): path to a BUILD file to add to the generated
`BUILD` file of a package. You cannot use both additive_build_content and additive_build_content_file
arguments at the same time.""",
        ),
        "copy_executables": attr.string_dict(
            doc = """\
(dict, optional): A mapping of `src` and `out` files for
[@bazel_skylib//rules:copy_file.bzl][cf]. Targets generated here will also be flagged as
executable.""",
        ),
        "copy_files": attr.string_dict(
            doc = """\
(dict, optional): A mapping of `src` and `out` files for 
[@bazel_skylib//rules:copy_file.bzl][cf]""",
        ),
        "data": attr.string_list(
            doc = """\
(list, optional): A list of labels to add as `data` dependencies to
the generated `py_library` target.""",
        ),
        "data_exclude_glob": attr.string_list(
            doc = """\
(list, optional): A list of exclude glob patterns to add as `data` to
the generated `py_library` target.""",
        ),
        "hub_name": attr.string(
            doc = """\
Name of the whl modification, hub we use this name to set the modifications for
pip.parse. If you have different pip hubs you can use a different name,
otherwise it is best practice to just use one.""",
            mandatory = True,
        ),
        "srcs_exclude_glob": attr.string_list(
            doc = """\
(list, optional): A list of labels to add as `srcs` to the generated
`py_library` target.""",
        ),
        "whl_name": attr.string(
            doc = "The whl name that the modifications are used for.",
            mandatory = True,
        ),
    }
    return attrs

pip = module_extension(
    doc = """\
pip.parse:
This tag class is used to create a pip hub and all of the spokes that are part of that hub.
We can have multiple different hubs, but we cannot have hubs that have the same name in
different modules.  Each hub needs one or more spokes.  A spoke contains a specific version
of Python, and the requirement(s) files that are unquie to that Python version.
In order to add more spokes you call this extension mulitiple times using the same hub
name.

pip.whl_mods:
This tag class is used to create different wheel modification JSON files.  These files
contain directives that are used by the wheel_installer.py during the creation of 
wheels.
""",
    implementation = _pip_impl,
    tag_classes = {
        "parse": tag_class(
            attrs = _pip_parse_ext_attrs(),
            doc = """\
This tag class is used to create a pip hub and all of the spokes that are part of that hub.
This tag class reuses the pip attributes that are found in 
@rules_python//python/pip_install:pip_repository.bzl
""",
        ),
        "whl_mods": tag_class(
            attrs = _mod_tag_attrs(),
            doc = """\
This tag class is used to create JSON file that are used when calling wheel_builder.py.  These
JSON files contain instructions on how to modify a wheel's project.  Each of the attributes
create different modifications based on the type of attribute. Previously to bzlmod these
JSON files where referred to as annotations, and were renamed to whl_modifications in this
extension.
""",
        ),
    },
)

def _whl_mods_repo_impl(rctx):
    rctx.file("BUILD.bazel", """\
exports_files(
    glob(["*.json"]),
    visibility = ["//visibility:public"],
)
""")

    for whl_name, mods in rctx.attr.whl_mods.items():
        rctx.file("{}.json".format(whl_name), mods)

_whl_mods_repo = repository_rule(
    doc = """\
This rule creates json files based on the whl_mods attribute. 
""",
    implementation = _whl_mods_repo_impl,
    attrs = {
        "whl_mods": attr.string_dict(
            mandatory = True,
            doc = "JSON endcoded string that is provided to wheel_builder.py",
        ),
    },
)
