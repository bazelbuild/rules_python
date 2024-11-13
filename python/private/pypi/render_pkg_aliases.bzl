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
    if len(aliases) == 1 and not aliases[0].version and not aliases[0].config_setting:
        return repr(aliases[0].repo)

    actual = {}
    for alias in aliases:
        actual[alias.config_setting or ("//_config:is_python_" + alias.version)] = alias.repo
    return render.indent(render.dict(actual)).lstrip()

def _render_common_aliases(*, name, aliases, extra_aliases = [], group_name = None):
    return """\
load("@rules_python//python/private/pypi:pkg_aliases.bzl", "pkg_aliases")

package(default_visibility = ["//visibility:public"])

pkg_aliases(
    name = "{name}",
    actual = {actual},
    group_name = {group_name},
    extra_aliases = {extra_aliases},
)""".format(
        name = name,
        actual = _repr_actual(aliases),
        group_name = repr(group_name),
        extra_aliases = repr(extra_aliases),
    )

def render_pkg_aliases(*, aliases, requirement_cycles = None, extra_hub_aliases = {}):
    """Create alias declarations for each PyPI package.

    The aliases should be appended to the pip_repository BUILD.bazel file. These aliases
    allow users to use requirement() without needed a corresponding `use_repo()` for each dep
    when using bzlmod.

    Args:
        aliases: dict, the keys are normalized distribution names and values are the
            whl_alias instances.
        requirement_cycles: any package groups to also add.
        extra_hub_aliases: The list of extra aliases for each whl to be added
          in addition to the default ones.

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
        ).strip()
        for name, pkg_aliases in aliases.items()
    }

    if requirement_cycles:
        files["_groups/BUILD.bazel"] = generate_group_library_build_bazel("", requirement_cycles)
    return files

def whl_alias(*, repo, version = None, config_setting = None, filename = None, target_platforms = None):
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
            to "//_config:is_python_{version}".
        filename: optional(str), the distribution filename to derive the config_setting.
        target_platforms: optional(list[str]), the list of target_platforms for this
            distribution.

    Returns:
        a struct with the validated and parsed values.
    """
    if not repo:
        fail("'repo' must be specified")

    if target_platforms:
        for p in target_platforms:
            if not p.startswith("cp"):
                fail("target_platform should start with 'cp' denoting the python version, got: " + p)

    def as_dict():
        ret = {
            "repo": repo,
        }
        if config_setting:
            ret["config_setting"] = config_setting
        if filename:
            ret["filename"] = filename
        if target_platforms:
            ret["target_platforms"] = target_platforms
        if version:
            ret["version"] = version
        return ret

    return struct(
        config_setting = config_setting,
        filename = filename,
        repo = repo,
        target_platforms = target_platforms,
        version = version,
        as_dict = as_dict,
    )

def render_multiplatform_pkg_aliases(*, aliases, **kwargs):
    """Render the multi-platform pkg aliases.

    Args:
        aliases: dict[str, list(whl_alias)] A list of aliases that will be
          transformed from ones having `filename` to ones having `config_setting`.
        **kwargs: extra arguments passed to render_pkg_aliases.

    Returns:
        A dict of file paths and their contents.
    """

    flag_versions = get_whl_flag_versions(
        aliases = [
            a
            for bunch in aliases.values()
            for a in bunch
        ],
    )

    config_setting_aliases = {
        pkg: multiplatform_whl_aliases(
            aliases = pkg_aliases,
            glibc_versions = flag_versions.get("glibc_versions", []),
            muslc_versions = flag_versions.get("muslc_versions", []),
            osx_versions = flag_versions.get("osx_versions", []),
        )
        for pkg, pkg_aliases in aliases.items()
    }

    contents = render_pkg_aliases(
        aliases = config_setting_aliases,
        **kwargs
    )
    contents["_config/BUILD.bazel"] = _render_config_settings(**flag_versions)
    return contents

def multiplatform_whl_aliases(*, aliases, **kwargs):
    """convert a list of aliases from filename to config_setting ones.

    Args:
        aliases: list(whl_alias): The aliases to process. Any aliases that have
            the filename set will be converted to a list of aliases, each with
            an appropriate config_setting value.
        **kwargs: Extra parameters passed to get_filename_config_settings.

    Returns:
        A dict with aliases to be used in the hub repo.
    """

    ret = []
    versioned_additions = {}
    for alias in aliases:
        if not alias.filename and not alias.target_platforms:
            ret.append(alias)
            continue

        config_settings, all_versioned_settings = get_filename_config_settings(
            # TODO @aignas 2024-05-27: pass the parsed whl to reduce the
            # number of duplicate operations.
            filename = alias.filename or "",
            target_platforms = alias.target_platforms,
            python_version = alias.version,
            # If we have multiple platforms but no wheel filename, lets use different
            # config settings.
            non_whl_prefix = "sdist" if alias.filename else "",
            **kwargs
        )

        for setting in config_settings:
            ret.append(whl_alias(
                repo = alias.repo,
                version = alias.version,
                config_setting = "//_config" + setting,
            ))

        # Now for the versioned platform config settings, we need to select one
        # that best fits the bill and if there are multiple wheels, e.g.
        # manylinux_2_17_x86_64 and manylinux_2_28_x86_64, then we need to select
        # the former when the glibc is in the range of [2.17, 2.28) and then chose
        # the later if it is [2.28, ...). If the 2.28 wheel was not present in
        # the hub, then we would need to use 2.17 for all the glibc version
        # configurations.
        #
        # Here we add the version settings to a dict where we key the range of
        # versions that the whl spans. If the wheel supports musl and glibc at
        # the same time, we do this for each supported platform, hence the
        # double dict.
        for default_setting, versioned in all_versioned_settings.items():
            versions = sorted(versioned)
            min_version = versions[0]
            max_version = versions[-1]

            versioned_additions.setdefault(default_setting, {})[(min_version, max_version)] = struct(
                repo = alias.repo,
                python_version = alias.version,
                settings = versioned,
            )

    versioned = {}
    for default_setting, candidates in versioned_additions.items():
        # Sort the candidates by the range of versions the span, so that we
        # start with the lowest version.
        for _, candidate in sorted(candidates.items()):
            # Set the default with the first candidate, which gives us the highest
            # compatibility. If the users want to use a higher-version than the default
            # they can configure the glibc_version flag.
            versioned.setdefault(default_setting, whl_alias(
                version = candidate.python_version,
                config_setting = "//_config" + default_setting,
                repo = candidate.repo,
            ))

            # We will be overwriting previously added entries, but that is intended.
            for _, setting in sorted(candidate.settings.items()):
                versioned[setting] = whl_alias(
                    version = candidate.python_version,
                    config_setting = "//_config" + setting,
                    repo = candidate.repo,
                )

    ret.extend(versioned.values())
    return ret

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

def get_whl_flag_versions(aliases):
    """Return all of the flag versions that is used by the aliases

    Args:
        aliases: list[whl_alias]

    Returns:
        dict, which may have keys:
          * python_versions
    """
    python_versions = {}
    glibc_versions = {}
    target_platforms = {}
    muslc_versions = {}
    osx_versions = {}

    for a in aliases:
        if not a.version and not a.filename:
            continue

        if a.version:
            python_versions[a.version] = None

        if a.filename and a.filename.endswith(".whl") and not a.filename.endswith("-any.whl"):
            parsed = parse_whl_name(a.filename)
        else:
            for plat in a.target_platforms or []:
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

def get_filename_config_settings(
        *,
        filename,
        target_platforms,
        python_version,
        glibc_versions = None,
        muslc_versions = None,
        osx_versions = None,
        non_whl_prefix = "sdist"):
    """Get the filename config settings.

    Args:
        filename: the distribution filename (can be a whl or an sdist).
        target_platforms: list[str], target platforms in "{abi}_{os}_{cpu}" format.
        glibc_versions: list[tuple[int, int]], list of versions.
        muslc_versions: list[tuple[int, int]], list of versions.
        osx_versions: list[tuple[int, int]], list of versions.
        python_version: the python version to generate the config_settings for.
        non_whl_prefix: the prefix of the config setting when the whl we don't have
            a filename ending with ".whl".

    Returns:
        A tuple:
         * A list of config settings that are generated by ./pip_config_settings.bzl
         * The list of default version settings.
    """
    prefixes = []
    suffixes = []
    setting_supported_versions = {}

    if filename.endswith(".whl"):
        if (0, 0) in glibc_versions:
            fail("Invalid version in 'glibc_versions': cannot specify (0, 0) as a value")
        if (0, 0) in muslc_versions:
            fail("Invalid version in 'muslc_versions': cannot specify (0, 0) as a value")
        if (0, 0) in osx_versions:
            fail("Invalid version in 'osx_versions': cannot specify (0, 0) as a value")

        glibc_versions = sorted(glibc_versions)
        muslc_versions = sorted(muslc_versions)
        osx_versions = sorted(osx_versions)

        parsed = parse_whl_name(filename)
        if parsed.python_tag == "py2.py3":
            py = "py"
        elif parsed.python_tag.startswith("cp"):
            py = "cp3x"
        else:
            py = "py3"

        if parsed.abi_tag.startswith("cp"):
            abi = "cp"
        else:
            abi = parsed.abi_tag

        if parsed.platform_tag == "any":
            prefixes = ["_{}_{}_any".format(py, abi)]
            suffixes = [_non_versioned_platform(p) for p in target_platforms or []]
        else:
            prefixes = ["_{}_{}".format(py, abi)]
            suffixes = _whl_config_setting_suffixes(
                platform_tag = parsed.platform_tag,
                glibc_versions = glibc_versions,
                muslc_versions = muslc_versions,
                osx_versions = osx_versions,
                setting_supported_versions = setting_supported_versions,
            )
    else:
        prefixes = [""] if not non_whl_prefix else ["_" + non_whl_prefix]
        suffixes = [_non_versioned_platform(p) for p in target_platforms or []]

    versioned = {
        ":is_cp{}{}_{}".format(python_version, p, suffix): {
            version: ":is_cp{}{}_{}".format(python_version, p, setting)
            for version, setting in versions.items()
        }
        for p in prefixes
        for suffix, versions in setting_supported_versions.items()
    }

    if suffixes or versioned:
        return [":is_cp{}{}_{}".format(python_version, p, s) for p in prefixes for s in suffixes], versioned
    else:
        return [":is_cp{}{}".format(python_version, p) for p in prefixes], setting_supported_versions

def _whl_config_setting_suffixes(
        platform_tag,
        glibc_versions,
        muslc_versions,
        osx_versions,
        setting_supported_versions):
    suffixes = []
    for platform_tag in platform_tag.split("."):
        for p in whl_target_platforms(platform_tag):
            prefix = p.os
            suffix = p.cpu
            if "manylinux" in platform_tag:
                prefix = "manylinux"
                versions = glibc_versions
            elif "musllinux" in platform_tag:
                prefix = "musllinux"
                versions = muslc_versions
            elif p.os in ["linux", "windows"]:
                versions = [(0, 0)]
            elif p.os == "osx":
                versions = osx_versions
                if "universal2" in platform_tag:
                    suffix += "_universal2"
            else:
                fail("Unsupported whl os: {}".format(p.os))

            default_version_setting = "{}_{}".format(prefix, suffix)
            supported_versions = {}
            for v in versions:
                if v == (0, 0):
                    suffixes.append(default_version_setting)
                elif v >= p.version:
                    supported_versions[v] = "{}_{}_{}_{}".format(
                        prefix,
                        v[0],
                        v[1],
                        suffix,
                    )
            if supported_versions:
                setting_supported_versions[default_version_setting] = supported_versions

    return suffixes
