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

"""Macro to generate all of the targets present in a {obj}`whl_library`."""

load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("//python:py_binary.bzl", "py_binary")
load("//python:py_library.bzl", "py_library")
load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    "WHEEL_ENTRY_POINT_PREFIX",
    "WHEEL_FILE_PUBLIC_LABEL",
)

def whl_library_targets(
        name,
        *,
        whl,
        dep_template,
        data_exclude = [],
        tags = [],
        filegroups = {
            DIST_INFO_LABEL: ["site-packages/*.dist-info/**"],
            DATA_LABEL: ["data/**"],
        },
        dependencies = [],
        dependencies_by_platform = {},
        copy_files = {},
        copy_executables = {},
        entry_points = {},
        native = native,
        rules = struct(
            copy_file = copy_file,
            py_binary = py_binary,
            py_library = py_library,
        )):
    """Create all of the whl_library targets.

    Args:
        name: {type}`str` Currently unused.
        filegroups: {type}`dict[str, list[str]]` A dictionary of the target
            names and the glob matches.
        dependencies: {type}`list[str]` A list of dependencies.
        dependencies_by_platform: {type}`dict[str, list[str]]` A list of
            dependencies by platform key.
        copy_executables: {type}`dict[str, str]` The mapping between src and
            dest locations for the targets.
        copy_files: {type}`dict[str, str]` The mapping between src and
            dest locations for the targets.
        entry_points: {type}`dict[str, str]` The mapping between the script
            name and the python file to use.
        native: {type}`native` The native struct for overriding in tests.
        rules: {type}`struct` A struct with references to rules for creating targets.
    """
    _ = name  # buildifier: @unused
    for name, glob in filegroups.items():
        native.filegroup(
            name = name,
            srcs = native.glob(glob, allow_empty = True),
            visibility = ["//visibility:public"],
        )

    for src, dest in copy_files.items():
        rules.copy_file(
            name = dest + ".copy",
            src = src,
            out = dest,
            visibility = ["//visibility:public"],
        )
    for src, dest in copy_executables.items():
        rules.copy_file(
            name = dest + ".copy",
            src = src,
            out = dest,
            is_executable = True,
            visibility = ["//visibility:public"],
        )

    _config_settings(
        dependencies_by_platform.keys(),
        native = native,
        visibility = ["//visibility:private"],
    )

    # TODO @aignas 2024-10-25: remove the entry_point generation once
    # `py_console_script_binary` is the only way to use entry points.
    for entry_point, entry_point_script_name in entry_points.items():
        rules.py_binary(
            name = "{}_{}".format(WHEEL_ENTRY_POINT_PREFIX, entry_point),
            # Ensure that this works on Windows as well - script may have Windows path separators.
            srcs = [entry_point_script_name.replace("\\", "/")],
            # This makes this directory a top-level in the python import
            # search path for anything that depends on this.
            imports = ["."],
            deps = [":" + PY_LIBRARY_PUBLIC_LABEL],
            visibility = ["//visibility:public"],
        )

    # TODO: to kwargs
    if hasattr(native, "filegroup"):
        native.filegroup(
            name = WHEEL_FILE_PUBLIC_LABEL,
            srcs = [whl],
            data = _deps(
                deps = dependencies,
                deps_by_platform = dependencies_by_platform,
                tmpl = dep_template.format(name = "{}", target = WHEEL_FILE_PUBLIC_LABEL),
                select = getattr(native, "select", select),
            ),
            visibility = ["//visibility:public"],
        )

    if hasattr(rules, "py_library"):
        _data_exclude = [
            "**/* *",
            "**/*.py",
            "**/*.pyc",
            "**/*.pyc.*",  # During pyc creation, temp files named *.pyc.NNNN are created
            # RECORD is known to contain sha256 checksums of files which might include the checksums
            # of generated files produced when wheels are installed. The file is ignored to avoid
            # Bazel caching issues.
            "**/*.dist-info/RECORD",
        ]
        for item in data_exclude:
            if item not in _data_exclude:
                _data_exclude.append(item)

        rules.py_library(
            name = PY_LIBRARY_PUBLIC_LABEL,
            srcs = native.glob(
                ["site-packages/**/*.py"],
                exclude = [],
                # Empty sources are allowed to support wheels that don't have any
                # pure-Python code, e.g. pymssql, which is written in Cython.
                allow_empty = True,
            ),
            data = [] + native.glob(
                ["site-packages/**/*"],
                exclude = _data_exclude,
            ),
            # This makes this directory a top-level in the python import
            # search path for anything that depends on this.
            imports = ["site-packages"],
            deps = _deps(
                deps = dependencies,
                deps_by_platform = dependencies_by_platform,
                tmpl = dep_template.format(name = "{}", target = PY_LIBRARY_PUBLIC_LABEL),
                select = getattr(native, "select", select),
            ),
            tags = tags,
            visibility = ["//visibility:public"],
        )

def _config_settings(dependencies_by_platform, native = native, **kwargs):
    """Generate config settings for the targets.

    Args:
        dependencies_by_platform: {type}`list[str]` platform keys, can be
            one of the following formats:
            * `//conditions:default`
            * `@platforms//os:{value}`
            * `@platforms//cpu:{value}`
            * `@//python/config_settings:is_python_3.{minor_version}`
            * `{os}_{cpu}`
            * `cp3{minor_version}_{os}_{cpu}`
        native: {type}`native` The native struct for overriding in tests.
        **kwargs: Extra kwargs to pass to the rule.
    """
    for p in dependencies_by_platform:
        if p.startswith("@") or p.endswith("default"):
            continue

        abi, _, tail = p.partition("_")
        if not abi.startswith("cp"):
            tail = p
            abi = ""

        os, _, arch = tail.partition("_")
        os = "" if os == "anyos" else os
        arch = "" if arch == "anyarch" else arch

        _kwargs = dict(kwargs)
        if arch:
            _kwargs.setdefault("constraint_values", []).append("@platforms//cpu:{}".format(arch))
        if os:
            _kwargs.setdefault("constraint_values", []).append("@platforms//os:{}".format(os))

        if abi:
            _kwargs["flag_values"] = {
                "@rules_python//python/config_settings:python_version_major_minor": "3.{minor_version}".format(
                    minor_version = abi[len("cp3"):],
                ),
            }

        native.config_setting(
            name = "is_{name}".format(
                name = p.replace("cp3", "python_3."),
            ),
            **_kwargs
        )

def _plat_label(plat):
    if plat.endswith("default"):
        return plat
    elif plat.startswith("@//"):
        return Label(plat.strip("@"))
    elif plat.startswith("@"):
        return plat
    else:
        return ":is_" + plat.replace("cp3", "python_3.")

def _deps(deps, deps_by_platform, tmpl, select = select):
    deps = [tmpl.format(d) for d in sorted(deps)]

    if not deps_by_platform:
        return deps

    deps_by_platform = {
        _plat_label(p): [
            tmpl.format(d)
            for d in sorted(deps)
        ]
        for p, deps in sorted(deps_by_platform.items())
    }

    # Add the default, which means that we will be just using the dependencies in
    # `deps` for platforms that are not handled in a special way by the packages
    deps_by_platform.setdefault("//conditions:default", [])

    if not deps:
        return select(deps_by_platform)
    else:
        return deps + select(deps_by_platform)
