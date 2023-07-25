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

"""render_pkg_aliases is a function to generate BUILD.bazel contents used to create user-friendly aliases.

This is used in bzlmod and non-bzlmod setups."""

load("//python/private:normalize_name.bzl", "normalize_name")
load(":version_label.bzl", "version_label")

_DEFAULT = """\
alias(
    name = "{name}",
    actual = "@{repo_name}_{dep}//:{target}",
)"""

_SELECT = """\
alias(
    name = "{name}",
    actual = select({{{selects}}}),
)"""

def _render_alias(
        *,
        name,
        repo_name,
        dep,
        target,
        versions,
        rules_python,
        default_version = None):
    """Render an alias for common targets

    If the versions is passed, then the `rules_python` must be passed as well and
    an alias with a select statement based on the python version is going to be
    generated.
    """
    if versions == None:
        return _DEFAULT.format(
            name = name,
            repo_name = repo_name,
            dep = dep,
            target = target,
        )

    # Create the alias repositories which contains different select
    # statements  These select statements point to the different pip
    # whls that are based on a specific version of Python.
    selects = {}
    for full_version in versions:
        condition = "@@{rules_python}//python/config_settings:is_python_{full_python_version}".format(
            rules_python = rules_python,
            full_python_version = full_version,
        )
        actual = "@{repo_name}_{version}_{dep}//:{target}".format(
            repo_name = repo_name,
            version = version_label(full_version),
            dep = dep,
            target = target,
        )
        selects[condition] = actual

    if default_version:
        default_actual = "@{repo_name}_{version}_{dep}//:{target}".format(
            repo_name = repo_name,
            version = version_label(default_version),
            dep = dep,
            target = target,
        )
        selects["//conditions:default"] = default_actual

    return _SELECT.format(
        name = name,
        selects = "\n{}    ".format(
            "".join([
                "        {}: {},\n".format(repr(k), repr(v))
                for k, v in selects.items()
            ]),
        ),
    )

def _render_entry_points(repo_name, dep, entry_points, default_version = None, rules_python = None, prefix = "rules_python_wheel_entry_point_"):
    return "\n\n".join([
        """package(default_visibility = ["//visibility:public"])""",
    ] + [
        _render_alias(
            name = normalize_name(script),
            repo_name = repo_name,
            dep = dep,
            target = prefix + normalize_name(script),
            versions = versions,
            default_version = default_version,
            rules_python = rules_python,
        )
        for script, versions in entry_points.items()
    ])

def _render_common_aliases(repo_name, name, versions = None, default_version = None, rules_python = None):
    return "\n\n".join([
        """package(default_visibility = ["//visibility:public"])""",
        _render_alias(
            name = name,
            repo_name = repo_name,
            dep = name,
            target = "pkg",
            versions = versions,
            default_version = default_version,
            rules_python = rules_python,
        ),
    ] + [
        _render_alias(
            name = target,
            repo_name = repo_name,
            dep = name,
            target = target,
            versions = versions,
            default_version = default_version,
            rules_python = rules_python,
        )
        for target in ["pkg", "whl", "data", "dist_info"]
    ])

def render_pkg_aliases(
        *,
        repo_name,
        bzl_packages = None,
        whl_map = None,
        whl_entry_points = None,
        rules_python = None,
        default_version = None):
    """Create alias declarations for each PyPI package.

    The aliases should be appended to the pip_repository BUILD.bazel file. These aliases
    allow users to use requirement() without needed a corresponding `use_repo()` for each dep
    when using bzlmod.

    Args:
        repo_name: the repository name of the hub repository that is visible to the users that is
            also used as the prefix for the spoke repo names (e.g. "pip", "pypi").
        bzl_packages: the list of packages to setup, if not specified, whl_map.keys() will be used instead.
        whl_map: the whl_map for generating Python version aware aliases.
        default_version: the default version to be used for the aliases.
        rules_python: the name of the rules_python workspace.

    Returns:
        A dict of file paths and their contents.
    """
    if not bzl_packages and whl_map:
        bzl_packages = list(whl_map.keys())

    contents = {}
    for name in bzl_packages:
        versions = None
        entry_points = None

        if whl_map != None:
            versions = whl_map[name]

        if whl_entry_points != None:
            entry_points = whl_entry_points.get(name, {})

        name = normalize_name(name)

        filename = "{}/BUILD.bazel".format(name)
        contents[filename] = _render_common_aliases(
            repo_name = repo_name,
            name = name,
            versions = versions,
            rules_python = rules_python,
            default_version = default_version,
        ).strip()

        if entry_points:
            # Generate aliases where we have the select statement
            filename = "{}/bin/BUILD.bazel".format(name)
            contents[filename] = _render_entry_points(
                repo_name = repo_name,
                dep = name,
                rules_python = rules_python,
                default_version = default_version,
                entry_points = entry_points,
            ).strip()

    return contents
