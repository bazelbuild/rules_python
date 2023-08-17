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
load(":text_util.bzl", "render")
load(":version_label.bzl", "version_label")

NO_MATCH_ERROR_MESSAGE_TEMPLATE = """\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
versions available for this wheel. This wheel supports the following Python versions:
    {supported_versions}

As matched by the `@{rules_python}//python/config_settings:is_python_<version>`
configuration settings.

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    {rules_python}//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
"""

def _render_whl_library_alias(
        *,
        name,
        repo_name,
        dep,
        target,
        default_version,
        versions,
        rules_python):
    """Render an alias for common targets

    If the versions is passed, then the `rules_python` must be passed as well and
    an alias with a select statement based on the python version is going to be
    generated.
    """
    if versions == None:
        return render.alias(
            name = name,
            actual = repr("@{repo_name}_{dep}//:{target}".format(
                repo_name = repo_name,
                dep = dep,
                target = target,
            )),
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
        no_match_error = None
        default_actual = "@{repo_name}_{version}_{dep}//:{target}".format(
            repo_name = repo_name,
            version = version_label(default_version),
            dep = dep,
            target = target,
        )
        selects["//conditions:default"] = default_actual
    else:
        no_match_error = "_NO_MATCH_ERROR"

    return render.alias(
        name = name,
        actual = render.select(
            selects,
            no_match_error = no_match_error,
        ),
    )

def _render_common_aliases(repo_name, name, versions = None, default_version = None, rules_python = None):
    lines = [
        """package(default_visibility = ["//visibility:public"])""",
    ]

    if versions:
        versions = sorted(versions)

    if versions and not default_version:
        error_msg = NO_MATCH_ERROR_MESSAGE_TEMPLATE.format(
            supported_versions = ", ".join(versions),
            rules_python = rules_python,
        )

        lines.append("_NO_MATCH_ERROR = \"\"\"\\\n{error_msg}\"\"\"".format(
            error_msg = error_msg,
        ))

    lines.append(
        render.alias(
            name = name,
            actual = repr(":pkg"),
        ),
    )
    lines.extend(
        [
            _render_whl_library_alias(
                name = target,
                repo_name = repo_name,
                dep = name,
                target = target,
                versions = versions,
                default_version = default_version,
                rules_python = rules_python,
            )
            for target in ["pkg", "whl", "data", "dist_info"]
        ],
    )

    return "\n\n".join(lines)

def render_pkg_aliases(*, repo_name, bzl_packages = None, whl_map = None, rules_python = None, default_version = None):
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
        if whl_map != None:
            versions = whl_map[name]
        name = normalize_name(name)

        filename = "{}/BUILD.bazel".format(name)
        contents[filename] = _render_common_aliases(
            repo_name = repo_name,
            name = name,
            versions = versions,
            rules_python = rules_python,
            default_version = default_version,
        ).strip()

    return contents
