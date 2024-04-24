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
        aliases):
    """Render an alias for common targets."""
    if len(aliases) == 1 and not aliases[0].version:
        alias = aliases[0]
        return render.alias(
            name = name,
            actual = repr("@{repo}//:{name}".format(repo = alias.repo, name = name)),
        )

    # Create the alias repositories which contains different select
    # statements  These select statements point to the different pip
    # whls that are based on a specific version of Python.
    selects = {}
    no_match_error = "_NO_MATCH_ERROR"
    default = None
    for alias in sorted(aliases, key = lambda x: x.version):
        actual = "@{repo}//:{name}".format(repo = alias.repo, name = name)
        selects[alias.config_setting] = actual
        if alias.version == default_version:
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

def _render_common_aliases(*, name, aliases, default_version = None):
    lines = [
        """package(default_visibility = ["//visibility:public"])""",
    ]

    versions = None
    if aliases:
        versions = sorted([v.version for v in aliases if v.version])

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
                aliases = aliases,
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
        aliases: dict, the keys are normalized distribution names and values are the
            whl_alias instances.
        default_version: the default version to be used for the aliases.

    Returns:
        A dict of file paths and their contents.
    """
    contents = {}
    if not aliases:
        return contents
    elif type(aliases) != type({}):
        fail("The aliases need to be provided as a dict, got: {}".format(type(aliases)))

    return {
        "{}/BUILD.bazel".format(normalize_name(name)): _render_common_aliases(
            name = normalize_name(name),
            aliases = pkg_aliases,
            default_version = default_version,
        ).strip()
        for name, pkg_aliases in aliases.items()
    }

def whl_alias(*, repo, version = None, config_setting = None):
    """The bzl_packages value used by by the render_pkg_aliases function.

    This contains the minimum amount of information required to generate correct
    aliases in a hub repository.

    Args:
        repo: str, the repo of where to find the things to be aliased.
        version: optional(str), the version of the python toolchain that this
            whl alias is for. If not set, then non-version aware aliases will be
            constructed. This is mainly used for better error messages when there
            is no match found during a select.
        config_setting: optional(Label or str), the config setting that we should use. Defaults
            to "@rules_python//python/config_settings:is_python_{version}".

    Returns:
        a struct with the validated and parsed values.
    """
    if not repo:
        fail("'repo' must be specified")

    if version:
        config_setting = config_setting or Label("//python/config_settings:is_python_" + version)
        config_setting = str(config_setting)

    return struct(
        repo = repo,
        version = version,
        config_setting = config_setting,
    )
