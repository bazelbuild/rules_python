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
    "PY_LIBRARY_IMPL_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    "WHEEL_FILE_IMPL_LABEL",
    "WHEEL_FILE_PUBLIC_LABEL",
)

_BUILD_TEMPLATE = """\
{loads}

package(default_visibility = ["//visibility:public"])

whl_library_targets(
    name = "unused",
    dependencies_by_platform = {dependencies_by_platform},
    copy_files = {copy_files},
    copy_executables = {copy_executables},
    entry_points = {entry_points},
)
"""

def generate_whl_library_build_bazel(
        *,
        dep_template,
        whl_name,
        dependencies,
        dependencies_by_platform,
        data_exclude,
        tags,
        entry_points,
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

    if annotation:
        for dest in annotation.copy_files.values():
            data.append(dest)
        for dest in annotation.copy_executables.values():
            data.append(dest)
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

    loads = [
        """load("@rules_python//python:defs.bzl", "py_library")""",
        """load("@rules_python//python/private/pypi:whl_library_targets.bzl", "whl_library_targets")""",
    ]

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
                loads = "\n".join(sorted(loads)),
                py_library_label = py_library_label,
                dependencies = render.indent(lib_dependencies, " " * 4).lstrip(),
                dependencies_by_platform = render.indent(
                    render.dict(dependencies_by_platform, value_repr = render.list),
                    " " * 4,
                ).lstrip(),
                copy_files = render.indent(
                    render.dict(annotation.copy_files or {} if annotation else {}),
                ).lstrip(),
                copy_executables = render.indent(
                    render.dict(annotation.copy_executables or {} if annotation else {}),
                ).lstrip(),
                entry_points = render.indent(render.dict(entry_points)).lstrip(),
                whl_file_deps = render.indent(whl_file_deps, " " * 4).lstrip(),
                data_exclude = repr(_data_exclude),
                whl_name = whl_name,
                whl_file_label = whl_file_label,
                tags = repr(tags),
                srcs_exclude = repr(srcs_exclude),
                data = repr(data),
                impl_vis = repr(impl_vis),
            ),
        ] + additional_content,
    )

    # NOTE: Ensure that we terminate with a new line
    return contents.rstrip() + "\n"
