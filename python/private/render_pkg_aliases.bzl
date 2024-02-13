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

load(":normalize_name.bzl", "normalize_name")
load(":text_util.bzl", "render")

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
        default_version,
        whl_repos):
    """Render an alias for common targets."""
    if len(whl_repos) == 1 and not whl_repos[0].version:
        repo = whl_repos[0]

        return render.alias(
            name = name,
            actual = repr("@{repo_prefix}{dep}//:{name}".format(
                repo_prefix = repo.repo_prefix,
                dep = repo.name,
                name = name,
            )),
        )

    # Create the alias repositories which contains different select
    # statements  These select statements point to the different pip
    # whls that are based on a specific version of Python.
    selects = {}
    no_match_error = "_NO_MATCH_ERROR"
    default = None
    for repo in sorted(whl_repos, key = lambda x: x.version):
        actual = "@{repo_prefix}{dep}//:{name}".format(
            repo_prefix = repo.repo_prefix,
            dep = repo.name,
            name = name,
        )
        selects[repo.config_setting] = actual
        if repo.version == default_version:
            default = actual
            no_match_error = None

    if default:
        selects["//conditions:default"] = default

    return render.alias(
        name = name,
        actual = render.select(
            selects,
            no_match_error = no_match_error,
        ),
    )

def _render_common_aliases(*, name, whl_repos, default_version = None):
    lines = [
        """package(default_visibility = ["//visibility:public"])""",
    ]

    versions = None
    if whl_repos:
        versions = sorted([v.version for v in whl_repos if v.version])

    if not versions or default_version in versions:
        pass
    else:
        error_msg = NO_MATCH_ERROR_MESSAGE_TEMPLATE.format(
            supported_versions = ", ".join(versions),
            rules_python = "rules_python",
        )

        lines.append("_NO_MATCH_ERROR = \"\"\"\\\n{error_msg}\"\"\"".format(
            error_msg = error_msg,
        ))

        # This is to simplify the code in _render_whl_library_alias and to ensure
        # that we don't pass a 'default_version' that is not in 'versions'.
        default_version = None

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
                default_version = default_version,
                whl_repos = whl_repos,
            )
            for target in ["pkg", "whl", "data", "dist_info"]
        ],
    )

    return "\n\n".join(lines)

def render_pkg_aliases(*, aliases, default_version = None):
    """Create alias declarations for each PyPI package.

    The aliases should be appended to the pip_repository BUILD.bazel file. These aliases
    allow users to use requirement() without needed a corresponding `use_repo()` for each dep
    when using bzlmod.

    Args:
        aliases: the bzl_packages for generating Python version aware aliases.
        default_version: the default version to be used for the aliases.

    Returns:
        A dict of file paths and their contents.
    """
    contents = {}
    if not aliases:
        return contents

    whl_map = {}
    for pkg in aliases:
        whl_map.setdefault(pkg.name, []).append(pkg)

    return {
        "{}/BUILD.bazel".format(name): _render_common_aliases(
            name = name,
            whl_repos = whl_repos,
            default_version = default_version,
        ).strip()
        for name, whl_repos in whl_map.items()
    }

def whl_alias(*, name, repo_prefix, version = None, config_setting = None):
    """The bzl_packages value used by by the render_pkg_aliases function.

    This contains the minimum amount of information required to generate correct
    aliases in a hub repository.

    Args:
        name: str, the name of the package.
        repo_prefix: str, the repo prefix of where to find the alias.
        version: optional(str), the version of the python toolchain that this
            whl alias is for. If not set, then non-version aware aliases will be
            constructed. This is mainly used for better error messages when there
            is no match found during a select.
        config_setting: optional(Label or str), the config setting that we should use. Defaults
            to "@rules_python//python/config_settings:is_python_{version}".

    Returns:
        a struct with the validated and parsed values.
    """
    if not repo_prefix:
        fail("'repo_prefix' must be specified")

    if version:
        config_setting = config_setting or Label("//python/config_settings:is_python_" + version)
        config_setting = str(config_setting)

    return struct(
        name = normalize_name(name),
        repo_prefix = repo_prefix,
        version = version,
        config_setting = config_setting,
    )
