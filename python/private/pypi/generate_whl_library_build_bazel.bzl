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

"""Generate the BUILD.bazel contents for a repo defined by a whl_library."""

load("//python/private:normalize_name.bzl", "normalize_name")
load("//python/private:text_util.bzl", "render")
load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
    "PY_LIBRARY_IMPL_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    "WHEEL_ENTRY_POINT_PREFIX",
    "WHEEL_FILE_IMPL_LABEL",
    "WHEEL_FILE_PUBLIC_LABEL",
)

_DEFAULT_MACRO_LOAD = "@rules_python//python/private/pypi:whl_library_macros.bzl"
_COPY_FILE_LOAD = "@bazel_skylib//rules:copy_file.bzl"

_COPY_FILE_TEMPLATE = """\
copy_file(
    name = "{dest}.copy",
    src = "{src}",
    out = "{dest}",
    is_executable = {is_executable},
)
"""

_ENTRY_POINT_RULE_TEMPLATE = """\
py_binary(
    name = "{name}",
    srcs = ["{src}"],
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
    deps = ["{pkg}"],
)
"""

_BUILD_TEMPLATE = """\
{loads}

package(default_visibility = ["//visibility:public"])

data_filegroup(name="{data_label}")
dist_info_filegroup(name="{dist_info_label}")
whl_file(
    name = "{whl_file_label}",
    srcs = ["{whl_name}"],
    deps = {whl_file_deps},
    visibility = {impl_vis},
)
whl_library(
    name = "{py_library_label}",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude={srcs_exclude},
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    deps = {dependencies},
    data = {data} + glob(
        ["site-packages/**/*"],
        exclude={data_exclude},
    ),
    tags = {tags},
    visibility = {impl_vis},
)
"""

def _plat_label(plat):
    if plat.endswith("default"):
        return plat
    if plat.startswith("@//"):
        return "@@" + str(Label("//:BUILD.bazel")).partition("//")[0].strip("@") + plat.strip("@")
    elif plat.startswith("@"):
        return str(Label(plat))
    else:
        return ":is_" + plat.replace("cp3", "python_3.")

def _render_list_and_select(deps, deps_by_platform, tmpl):
    deps = render.list([tmpl.format(d) for d in sorted(deps)])

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
    deps_by_platform = render.select(deps_by_platform, value_repr = render.list)

    if deps == "[]":
        return deps_by_platform
    else:
        return "{} + {}".format(deps, deps_by_platform)

def _render_config_settings(dependencies_by_platform):
    loads = {}
    additional_content = []
    for p in dependencies_by_platform:
        # p can be one of the following formats:
        # * //conditions:default
        # * @platforms//os:{value}
        # * @platforms//cpu:{value}
        # * @//python/config_settings:is_python_3.{minor_version}
        # * {os}_{cpu}
        # * cp3{minor_version}_{os}_{cpu}
        if p.startswith("@") or p.endswith("default"):
            continue

        abi, _, tail = p.partition("_")
        if not abi.startswith("cp"):
            tail = p
            abi = ""

        os, _, arch = tail.partition("_")
        os = "" if os == "anyos" else os
        arch = "" if arch == "anyarch" else arch

        constraint_values = []
        if arch:
            constraint_values.append("@platforms//cpu:{}".format(arch))
        if os:
            constraint_values.append("@platforms//os:{}".format(os))

        constraint_values_str = render.indent(render.list(constraint_values)).lstrip()

        if abi:
            if not loads:
                loads["is_python_config_setting"] = "@rules_python//python/config_settings:config_settings.bzl"

            additional_content.append(
                """\
is_python_config_setting(
    name = "is_{name}",
    python_version = "3.{minor_version}",
    constraint_values = {constraint_values},
    visibility = ["//visibility:private"],
)""".format(
                    name = p.replace("cp3", "python_3."),
                    minor_version = abi[len("cp3"):],
                    constraint_values = constraint_values_str,
                ),
            )
        else:
            additional_content.append(
                """\
config_setting(
    name = "is_{name}",
    constraint_values = {constraint_values},
    visibility = ["//visibility:private"],
)""".format(
                    name = p.replace("cp3", "python_3."),
                    constraint_values = constraint_values_str,
                ),
            )

    return loads, "\n\n".join(additional_content)

def generate_whl_library_build_bazel(
        *,
        dep_template,
        whl_name,
        dependencies,
        dependencies_by_platform,
        data_exclude,
        tags,
        entry_points,
        override_loads = {},
        annotation = None,
        group_name = None,
        group_deps = []):
    """Generate a BUILD file for an unzipped Wheel

    Args:
        dep_template: the dependency template that should be used for dependency lists.
        whl_name: the whl_name that this is generated for.
        dependencies: a list of PyPI packages that are dependencies to the py_library.
        dependencies_by_platform: a dict[str, list] of PyPI packages that may vary by platform.
        data_exclude: more patterns to exclude from the data attribute of generated py_library rules.
        tags: list of tags to apply to generated py_library rules.
        entry_points: A dict of entry points to add py_binary rules for.
        annotation: The annotation for the build file.
        group_name: Optional[str]; name of the dependency group (if any) which contains this library.
          If set, this library will behave as a shim to group implementation rules which will provide
          simultaneously installed dependencies which would otherwise form a cycle.
        group_deps: List[str]; names of fellow members of the group (if any). These will be excluded
          from generated deps lists so as to avoid direct cycles. These dependencies will be provided
          at runtime by the group rules which wrap this library and its fellows together.
        override_loads: dict[str, str], the dictionary for the symbols to be
            used for defining standard targets. If the key within dict does not
            correspond to a symbol, it will fail.

    Returns:
        A complete BUILD file as a string
    """

    additional_content = []
    data = []
    srcs_exclude = []
    data_exclude = [] + data_exclude
    dependencies = sorted([normalize_name(d) for d in dependencies])
    dependencies_by_platform = {
        platform: sorted([normalize_name(d) for d in deps])
        for platform, deps in dependencies_by_platform.items()
    }
    tags = sorted(tags)

    for entry_point, entry_point_script_name in entry_points.items():
        additional_content.append(
            _generate_entry_point_rule(
                name = "{}_{}".format(WHEEL_ENTRY_POINT_PREFIX, entry_point),
                script = entry_point_script_name,
                pkg = ":" + PY_LIBRARY_PUBLIC_LABEL,
            ),
        )

    if annotation:
        for src, dest in annotation.copy_files.items():
            data.append(dest)
            additional_content.append(_generate_copy_commands(src, dest))
        for src, dest in annotation.copy_executables.items():
            data.append(dest)
            additional_content.append(
                _generate_copy_commands(src, dest, is_executable = True),
            )
        data.extend(annotation.data)
        data_exclude.extend(annotation.data_exclude_glob)
        srcs_exclude.extend(annotation.srcs_exclude_glob)
        if annotation.additive_build_content:
            additional_content.append(annotation.additive_build_content)

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

    # Ensure this list is normalized
    # Note: mapping used as set
    group_deps = {
        normalize_name(d): True
        for d in group_deps
    }

    dependencies = [
        d
        for d in dependencies
        if d not in group_deps
    ]
    dependencies_by_platform = {
        p: deps
        for p, deps in dependencies_by_platform.items()
        for deps in [[d for d in deps if d not in group_deps]]
        if deps
    }

    loads = {
        "copy_file": _COPY_FILE_LOAD,
        "data_filegroup": _DEFAULT_MACRO_LOAD,
        "dist_info_filegroup": _DEFAULT_MACRO_LOAD,
        "py_binary": "@rules_python//python:py_binary.bzl",
        "whl_file": _DEFAULT_MACRO_LOAD,
        "whl_library": _DEFAULT_MACRO_LOAD,
    }
    for symbol, location in override_loads.items():
        if symbol in loads:
            loads[symbol] = location
        else:
            msg = "Unsupported symbol name '{}', use one of: {}".format(symbol, sorted(loads))
            fail(msg)

    loads_, config_settings_content = _render_config_settings(dependencies_by_platform)
    if config_settings_content:
        for symbol, loc in loads_.items():
            loads[symbol] = loc
        additional_content.append(config_settings_content)

    lib_dependencies = _render_list_and_select(
        deps = dependencies,
        deps_by_platform = dependencies_by_platform,
        tmpl = dep_template.format(name = "{}", target = PY_LIBRARY_PUBLIC_LABEL),
    )

    whl_file_deps = _render_list_and_select(
        deps = dependencies,
        deps_by_platform = dependencies_by_platform,
        tmpl = dep_template.format(name = "{}", target = WHEEL_FILE_PUBLIC_LABEL),
    )

    # If this library is a member of a group, its public label aliases need to
    # point to the group implementation rule not the implementation rules. We
    # also need to mark the implementation rules as visible to the group
    # implementation.
    if group_name and "//:" in dep_template:
        # This is the legacy behaviour where the group library is outside the hub repo
        label_tmpl = dep_template.format(
            name = "_groups",
            target = normalize_name(group_name) + "_{}",
        )
        impl_vis = [dep_template.format(
            name = "_groups",
            target = "__pkg__",
        )]
        additional_content.extend([
            "",
            render.alias(
                name = PY_LIBRARY_PUBLIC_LABEL,
                actual = repr(label_tmpl.format(PY_LIBRARY_PUBLIC_LABEL)),
            ),
            "",
            render.alias(
                name = WHEEL_FILE_PUBLIC_LABEL,
                actual = repr(label_tmpl.format(WHEEL_FILE_PUBLIC_LABEL)),
            ),
        ])
        py_library_label = PY_LIBRARY_IMPL_LABEL
        whl_file_label = WHEEL_FILE_IMPL_LABEL

    elif group_name:
        py_library_label = PY_LIBRARY_PUBLIC_LABEL
        whl_file_label = WHEEL_FILE_PUBLIC_LABEL
        impl_vis = [dep_template.format(name = "", target = "__subpackages__")]

    else:
        py_library_label = PY_LIBRARY_PUBLIC_LABEL
        whl_file_label = WHEEL_FILE_PUBLIC_LABEL
        impl_vis = ["//visibility:public"]

    contents = "\n".join(
        [
            _BUILD_TEMPLATE.format(
                loads = _render_loads(loads),
                py_library_label = py_library_label,
                dependencies = render.indent(lib_dependencies, " " * 4).lstrip(),
                whl_file_deps = render.indent(whl_file_deps, " " * 4).lstrip(),
                data_exclude = repr(_data_exclude),
                whl_name = whl_name,
                whl_file_label = whl_file_label,
                tags = repr(tags),
                data_label = DATA_LABEL,
                dist_info_label = DIST_INFO_LABEL,
                srcs_exclude = repr(srcs_exclude),
                data = repr(data),
                impl_vis = repr(impl_vis),
            ),
        ] + additional_content,
    )

    # NOTE: Ensure that we terminate with a new line
    return contents.rstrip() + "\n"

def _generate_copy_commands(src, dest, is_executable = False):
    """Generate a [@bazel_skylib//rules:copy_file.bzl%copy_file][cf] target

    [cf]: https://github.com/bazelbuild/bazel-skylib/blob/1.1.1/docs/copy_file_doc.md

    Args:
        src (str): The label for the `src` attribute of [copy_file][cf]
        dest (str): The label for the `out` attribute of [copy_file][cf]
        is_executable (bool, optional): Whether or not the file being copied is executable.
            sets `is_executable` for [copy_file][cf]

    Returns:
        str: A `copy_file` instantiation.
    """
    return _COPY_FILE_TEMPLATE.format(
        src = src,
        dest = dest,
        is_executable = is_executable,
    )

def _generate_entry_point_rule(*, name, script, pkg):
    """Generate a Bazel `py_binary` rule for an entry point script.

    Note that the script is used to determine the name of the target. The name of
    entry point targets should be uniuqe to avoid conflicts with existing sources or
    directories within a wheel.

    Args:
        name (str): The name of the generated py_binary.
        script (str): The path to the entry point's python file.
        pkg (str): The package owning the entry point. This is expected to
            match up with the `py_library` defined for each repository.

    Returns:
        str: A `py_binary` instantiation.
    """
    return _ENTRY_POINT_RULE_TEMPLATE.format(
        name = name,
        src = script.replace("\\", "/"),
        pkg = pkg,
    )

def _render_loads(loads):
    by_import = {}
    for symbol, loc in loads.items():
        by_import.setdefault(loc, []).append(symbol)

    lines = []
    for loc, symbols in sorted(by_import.items()):
        if len(symbols) == 1:
            line = "load({}, {})".format(repr(loc), repr(symbols[0]))
        else:
            line = "load(\n{}\n)".format(render.indent("\n".join(
                [repr(item) + "," for item in [loc] + sorted(symbols)],
            )))

        lines.append(line)

    return "\n".join(lines)
