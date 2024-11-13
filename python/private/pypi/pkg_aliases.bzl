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

"""pkg_aliases is a macro to generate aliases for selecting the right wheel for the right target platform.

This is used in bzlmod and non-bzlmod setups."""

load("//python/private:text_util.bzl", "render")
load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
    "PY_LIBRARY_IMPL_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    "WHEEL_FILE_IMPL_LABEL",
    "WHEEL_FILE_PUBLIC_LABEL",
)

_NO_MATCH_ERROR_TEMPLATE = """\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
wheels available for this wheel. This wheel supports the following Python
configuration settings:
    {config_settings}

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    {rules_python}//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
"""

def _no_match_error(actual):
    if type(actual) != type({}):
        return None

    if "//conditions:default" in actual:
        return None

    return _NO_MATCH_ERROR_TEMPLATE.format(
        config_settings = render.indent(
            "\n".join(sorted(actual.keys())),
        ).lstrip(),
        rules_python = "rules_python",
    )

def pkg_aliases(
        *,
        name,
        actual,
        group_name = None,
        extra_aliases = None,
        native = native,
        select = select):
    """Create aliases for an actual package.

    Args:
        name: {type}`str` The name of the package.
        actual: {type}`dict[Label, str] | str` The config settings for the package
            mapping to repositories.
        group_name: {type}`str` The group name that the pkg belongs to.
        extra_aliases: {type}`list[str]` The extra aliases to be created.
        native: {type}`struct` used in unit tests.
        select: {type}`select` used in unit tests.
    """
    native.alias(
        name = name,
        actual = ":" + PY_LIBRARY_PUBLIC_LABEL,
    )

    target_names = {
        PY_LIBRARY_PUBLIC_LABEL: PY_LIBRARY_IMPL_LABEL if group_name else PY_LIBRARY_PUBLIC_LABEL,
        WHEEL_FILE_PUBLIC_LABEL: WHEEL_FILE_IMPL_LABEL if group_name else WHEEL_FILE_PUBLIC_LABEL,
        DATA_LABEL: DATA_LABEL,
        DIST_INFO_LABEL: DIST_INFO_LABEL,
    } | {
        x: x
        for x in extra_aliases or []
    }
    no_match_error = _no_match_error(actual)

    for name, target_name in target_names.items():
        if type(actual) == type(""):
            _actual = "@{repo}//:{target_name}".format(
                repo = actual,
                target_name = name,
            )
        elif type(actual) == type({}):
            _actual = select(
                {
                    config_setting: "@{repo}//:{target_name}".format(
                        repo = repo,
                        target_name = name,
                    )
                    for config_setting, repo in actual.items()
                },
                no_match_error = no_match_error,
            )
        else:
            fail("BUG: should have a dictionary or a string")

        kwargs = {}
        if target_name.startswith("_"):
            kwargs["visibility"] = ["//_groups:__subpackages__"]

        native.alias(
            name = target_name,
            actual = _actual,
            **kwargs
        )

    if group_name:
        native.alias(
            name = PY_LIBRARY_PUBLIC_LABEL,
            actual = "//_groups:{}_pkg".format(group_name),
        )
        native.alias(
            name = WHEEL_FILE_PUBLIC_LABEL,
            actual = "//_groups:{}_whl".format(group_name),
        )
