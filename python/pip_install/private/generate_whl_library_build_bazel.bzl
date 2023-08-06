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

_WHEEL_FILE_LABEL = "whl"
_PY_LIBRARY_LABEL = "pkg"
_DATA_LABEL = "data"
_DIST_INFO_LABEL = "dist_info"
_WHEEL_ENTRY_POINT_PREFIX = "rules_python_wheel_entry_point"

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
load("@rules_python//python:defs.bzl", "py_library", "py_binary")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "{dist_info_label}",
    srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
)

filegroup(
    name = "{data_label}",
    srcs = glob(["data/**"], allow_empty = True),
)

filegroup(
    name = "{whl_file_label}",
    srcs = glob(["*.whl"], allow_empty = True),
    data = {whl_file_deps},
)

py_library(
    name = "{name}",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude={srcs_exclude},
        # Empty sources are allowed to support wheels that don't have any
        # pure-Python code, e.g. pymssql, which is written in Cython.
        allow_empty = True,
    ),
    data = {data} + glob(
        ["site-packages/**/*"],
        exclude={data_exclude},
    ),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["site-packages"],
    deps = {dependencies},
    tags = {tags},
)
"""

def generate_whl_library_build_bazel(
        repo_prefix,
        dependencies,
        data_exclude,
        tags,
        entry_points,
        annotation = None):
    """Generate a BUILD file for an unzipped Wheel

    Args:
        repo_prefix: the repo prefix that should be used for dependency lists.
        dependencies: a list of PyPI packages that are dependencies to the py_library.
        data_exclude: more patterns to exclude from the data attribute of generated py_library rules.
        tags: list of tags to apply to generated py_library rules.
        entry_points: A dict of entry points to add py_binary rules for.
        annotation: The annotation for the build file.

    Returns:
        A complete BUILD file as a string
    """

    additional_content = []
    data = []
    srcs_exclude = []
    data_exclude = [] + data_exclude
    dependencies = sorted(dependencies)
    tags = sorted(tags)

    for entry_point, entry_point_script_name in entry_points.items():
        additional_content.append(
            _generate_entry_point_rule(
                name = "{}_{}".format(_WHEEL_ENTRY_POINT_PREFIX, entry_point),
                script = entry_point_script_name,
                pkg = ":" + _PY_LIBRARY_LABEL,
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

    lib_dependencies = [
        "@" + repo_prefix + normalize_name(d) + "//:" + _PY_LIBRARY_LABEL
        for d in dependencies
    ]
    whl_file_deps = [
        "@" + repo_prefix + normalize_name(d) + "//:" + _WHEEL_FILE_LABEL
        for d in dependencies
    ]

    contents = "\n".join(
        [
            _BUILD_TEMPLATE.format(
                name = _PY_LIBRARY_LABEL,
                dependencies = repr(lib_dependencies),
                data_exclude = repr(_data_exclude),
                whl_file_label = _WHEEL_FILE_LABEL,
                whl_file_deps = repr(whl_file_deps),
                tags = repr(tags),
                data_label = _DATA_LABEL,
                dist_info_label = _DIST_INFO_LABEL,
                entry_point_prefix = _WHEEL_ENTRY_POINT_PREFIX,
                srcs_exclude = repr(srcs_exclude),
                data = repr(data),
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
