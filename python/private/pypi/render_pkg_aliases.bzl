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
load("//python/private:text_util.bzl", "render")
load(
    ":generate_group_library_build_bazel.bzl",
    "generate_group_library_build_bazel",
)  # buildifier: disable=bzl-visibility
load(":parse_whl_name.bzl", "parse_whl_name")
load(":whl_target_platforms.bzl", "whl_target_platforms")

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

NO_MATCH_ERROR_MESSAGE_TEMPLATE_V2 = """\
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

def _repr_actual(aliases):
    if type(aliases) == type(""):
        return repr(aliases)

    actual = {}
    for alias, repo in aliases.items():
        if alias.filename:
            config_setting = """whl_config_setting(\n{}\n)""".format(
                render.indent("\n".join([
                    "{} = {},".format(k, repr(v))
                    for k, v in {
                        "filename": alias.filename,
                        "target_platforms": alias.target_platforms,
                        "version": alias.version,
                    }.items()
                    if v
                ])),
            )
        else:
            config_setting = repr(
                alias.config_setting or ("//_config:is_python_" + alias.version),
            )
        actual[config_setting] = repo

    return render.indent(render.dict(actual, key_repr = lambda x: x)).lstrip()

def _render_common_aliases(*, name, aliases, extra_aliases = [], group_name = None, **kwargs):
    actual_repr = _repr_actual(aliases)
    extra_loads = ""
    if "whl_config_setting" in actual_repr:
        extra_loads = """load("@rules_python//python/private/pypi:whl_config_setting.bzl", "whl_config_setting")"""
        extra_loads += "\n"

    return """\
load("@rules_python//python/private/pypi:pkg_aliases.bzl", "pkg_aliases")
{extra_loads}
package(default_visibility = ["//visibility:public"])

pkg_aliases(
    name = "{name}",
    actual = {actual},
    group_name = {group_name},
    extra_aliases = {extra_aliases},
{kwargs})""".format(
        extra_loads = extra_loads,
        name = name,
        actual = actual_repr,
        group_name = repr(group_name),
        extra_aliases = repr(extra_aliases),
        kwargs = "" if not kwargs else (
            render.indent(
                "\n".join([
                    "{} = {},".format(k, repr(v))
                    for k, v in kwargs.items()
                ]),
            ) + "\n"
        ),
    )

def render_pkg_aliases(*, aliases, requirement_cycles = None, extra_hub_aliases = {}, **kwargs):
    """Create alias declarations for each PyPI package.

    The aliases should be appended to the pip_repository BUILD.bazel file. These aliases
    allow users to use requirement() without needed a corresponding `use_repo()` for each dep
    when using bzlmod.

    Args:
        aliases: dict, the keys are normalized distribution names and values are the
            whl_config_setting instances.
        requirement_cycles: any package groups to also add.
        extra_hub_aliases: The list of extra aliases for each whl to be added
          in addition to the default ones.
        **kwargs: Extra kwargs to pass to the rules.

    Returns:
        A dict of file paths and their contents.
    """
    contents = {}
    if not aliases:
        return contents
    elif type(aliases) != type({}):
        fail("The aliases need to be provided as a dict, got: {}".format(type(aliases)))

    whl_group_mapping = {}
    if requirement_cycles:
        requirement_cycles = {
            name: [normalize_name(whl_name) for whl_name in whls]
            for name, whls in requirement_cycles.items()
        }

        whl_group_mapping = {
            whl_name: group_name
            for group_name, group_whls in requirement_cycles.items()
            for whl_name in group_whls
        }

    files = {
        "{}/BUILD.bazel".format(normalize_name(name)): _render_common_aliases(
            name = normalize_name(name),
            aliases = pkg_aliases,
            extra_aliases = extra_hub_aliases.get(normalize_name(name), []),
            group_name = whl_group_mapping.get(normalize_name(name)),
            **kwargs
        ).strip()
        for name, pkg_aliases in aliases.items()
    }

    if requirement_cycles:
        files["_groups/BUILD.bazel"] = generate_group_library_build_bazel("", requirement_cycles)
    return files

def render_multiplatform_pkg_aliases(*, aliases, **kwargs):
    """Render the multi-platform pkg aliases.

    Args:
        aliases: dict[str, list(whl_config_setting)] A list of aliases that will be
          transformed from ones having `filename` to ones having `config_setting`.
        **kwargs: extra arguments passed to render_pkg_aliases.

    Returns:
        A dict of file paths and their contents.
    """

    flag_versions = get_whl_flag_versions(
        settings = [
            a
            for bunch in aliases.values()
            for a in bunch
        ],
    )

    contents = render_pkg_aliases(
        aliases = aliases,
        glibc_versions = flag_versions.get("glibc_versions", []),
        muslc_versions = flag_versions.get("muslc_versions", []),
        osx_versions = flag_versions.get("osx_versions", []),
        **kwargs
    )
    contents["_config/BUILD.bazel"] = _render_config_settings(**flag_versions)
    return contents

def _render_config_settings(python_versions = [], target_platforms = [], osx_versions = [], glibc_versions = [], muslc_versions = []):
    return """\
load("@rules_python//python/private/pypi:config_settings.bzl", "config_settings")

config_settings(
    name = "config_settings",
    glibc_versions = {glibc_versions},
    muslc_versions = {muslc_versions},
    osx_versions = {osx_versions},
    python_versions = {python_versions},
    target_platforms = {target_platforms},
    visibility = ["//:__subpackages__"],
)""".format(
        glibc_versions = render.indent(render.list(glibc_versions)).lstrip(),
        muslc_versions = render.indent(render.list(muslc_versions)).lstrip(),
        osx_versions = render.indent(render.list(osx_versions)).lstrip(),
        python_versions = render.indent(render.list(python_versions)).lstrip(),
        target_platforms = render.indent(render.list(target_platforms)).lstrip(),
    )

def get_whl_flag_versions(settings):
    """Return all of the flag versions that is used by the settings

    Args:
        settings: list[whl_config_setting]

    Returns:
        dict, which may have keys:
          * python_versions
    """
    python_versions = {}
    glibc_versions = {}
    target_platforms = {}
    muslc_versions = {}
    osx_versions = {}

    for setting in settings:
        if not setting.version and not setting.filename:
            continue

        if setting.version:
            python_versions[setting.version] = None

        if setting.filename and setting.filename.endswith(".whl") and not setting.filename.endswith("-any.whl"):
            parsed = parse_whl_name(setting.filename)
        else:
            for plat in setting.target_platforms or []:
                target_platforms[_non_versioned_platform(plat)] = None
            continue

        for platform_tag in parsed.platform_tag.split("."):
            parsed = whl_target_platforms(platform_tag)

            for p in parsed:
                target_platforms[p.target_platform] = None

            if platform_tag.startswith("win") or platform_tag.startswith("linux"):
                continue

            head, _, tail = platform_tag.partition("_")
            major, _, tail = tail.partition("_")
            minor, _, tail = tail.partition("_")
            if tail:
                version = (int(major), int(minor))
                if "many" in head:
                    glibc_versions[version] = None
                elif "musl" in head:
                    muslc_versions[version] = None
                elif "mac" in head:
                    osx_versions[version] = None
                else:
                    fail(platform_tag)

    return {
        k: sorted(v)
        for k, v in {
            "glibc_versions": glibc_versions,
            "muslc_versions": muslc_versions,
            "osx_versions": osx_versions,
            "python_versions": python_versions,
            "target_platforms": target_platforms,
        }.items()
        if v
    }

def _non_versioned_platform(p, *, strict = False):
    """A small utility function that converts 'cp311_linux_x86_64' to 'linux_x86_64'.

    This is so that we can tighten the code structure later by using strict = True.
    """
    has_abi = p.startswith("cp")
    if has_abi:
        return p.partition("_")[-1]
    elif not strict:
        return p
    else:
        fail("Expected to always have a platform in the form '{{abi}}_{{os}}_{{arch}}', got: {}".format(p))
