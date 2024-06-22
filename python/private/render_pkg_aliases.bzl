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

load(
    "//python/pip_install/private:generate_group_library_build_bazel.bzl",
    "generate_group_library_build_bazel",
)  # buildifier: disable=bzl-visibility
load("//python/private/pypi:parse_whl_name.bzl", "parse_whl_name")
load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
    "PY_LIBRARY_IMPL_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    "WHEEL_FILE_IMPL_LABEL",
    "WHEEL_FILE_PUBLIC_LABEL",
)
load(":normalize_name.bzl", "normalize_name")
load(":text_util.bzl", "render")
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

def _render_whl_library_alias(
        *,
        name,
        default_config_setting,
        aliases,
        target_name,
        **kwargs):
    """Render an alias for common targets."""
    if len(aliases) == 1 and not aliases[0].version:
        alias = aliases[0]
        return render.alias(
            name = name,
            actual = repr("@{repo}//:{name}".format(
                repo = alias.repo,
                name = target_name,
            )),
            **kwargs
        )

    # Create the alias repositories which contains different select
    # statements  These select statements point to the different pip
    # whls that are based on a specific version of Python.
    selects = {}
    no_match_error = "_NO_MATCH_ERROR"
    for alias in sorted(aliases, key = lambda x: x.version):
        actual = "@{repo}//:{name}".format(repo = alias.repo, name = target_name)
        selects.setdefault(actual, []).append(alias.config_setting)
        if alias.config_setting == default_config_setting:
            selects[actual].append("//conditions:default")
            no_match_error = None

    return render.alias(
        name = name,
        actual = render.select(
            {
                tuple(sorted(
                    conditions,
                    # Group `is_python` and other conditions for easier reading
                    # when looking at the generated files.
                    key = lambda condition: ("is_python" not in condition, condition),
                )): target
                for target, conditions in sorted(selects.items())
            },
            no_match_error = no_match_error,
            # This key_repr is used to render selects.with_or keys
            key_repr = lambda x: repr(x[0]) if len(x) == 1 else render.tuple(x),
            name = "selects.with_or",
        ),
        **kwargs
    )

def _render_common_aliases(*, name, aliases, default_config_setting = None, group_name = None):
    lines = [
        """load("@bazel_skylib//lib:selects.bzl", "selects")""",
        """package(default_visibility = ["//visibility:public"])""",
    ]

    config_settings = None
    if aliases:
        config_settings = sorted([v.config_setting for v in aliases if v.config_setting])

    if not config_settings or default_config_setting in config_settings:
        pass
    else:
        error_msg = NO_MATCH_ERROR_MESSAGE_TEMPLATE_V2.format(
            config_settings = render.indent(
                "\n".join(config_settings),
            ).lstrip(),
            rules_python = "rules_python",
        )

        lines.append("_NO_MATCH_ERROR = \"\"\"\\\n{error_msg}\"\"\"".format(
            error_msg = error_msg,
        ))

        # This is to simplify the code in _render_whl_library_alias and to ensure
        # that we don't pass a 'default_version' that is not in 'versions'.
        default_config_setting = None

    lines.append(
        render.alias(
            name = name,
            actual = repr(":pkg"),
        ),
    )
    lines.extend(
        [
            _render_whl_library_alias(
                name = name,
                default_config_setting = default_config_setting,
                aliases = aliases,
                target_name = target_name,
                visibility = ["//_groups:__subpackages__"] if name.startswith("_") else None,
            )
            for target_name, name in {
                PY_LIBRARY_PUBLIC_LABEL: PY_LIBRARY_IMPL_LABEL if group_name else PY_LIBRARY_PUBLIC_LABEL,
                WHEEL_FILE_PUBLIC_LABEL: WHEEL_FILE_IMPL_LABEL if group_name else WHEEL_FILE_PUBLIC_LABEL,
                DATA_LABEL: DATA_LABEL,
                DIST_INFO_LABEL: DIST_INFO_LABEL,
            }.items()
        ],
    )
    if group_name:
        lines.extend(
            [
                render.alias(
                    name = "pkg",
                    actual = repr("//_groups:{}_pkg".format(group_name)),
                ),
                render.alias(
                    name = "whl",
                    actual = repr("//_groups:{}_whl".format(group_name)),
                ),
            ],
        )

    return "\n\n".join(lines)

def render_pkg_aliases(*, aliases, default_config_setting = None, requirement_cycles = None):
    """Create alias declarations for each PyPI package.

    The aliases should be appended to the pip_repository BUILD.bazel file. These aliases
    allow users to use requirement() without needed a corresponding `use_repo()` for each dep
    when using bzlmod.

    Args:
        aliases: dict, the keys are normalized distribution names and values are the
            whl_alias instances.
        default_config_setting: the default to be used for the aliases.
        requirement_cycles: any package groups to also add.

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
            default_config_setting = default_config_setting,
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

    if version:
        config_setting = config_setting or ("//_config:is_python_" + version)
        config_setting = str(config_setting)

    return struct(
        repo = repo,
        version = version,
        config_setting = config_setting,
        filename = filename,
        target_platforms = target_platforms,
    )

def render_multiplatform_pkg_aliases(*, aliases, default_version = None, **kwargs):
    """Render the multi-platform pkg aliases.

    Args:
        aliases: dict[str, list(whl_alias)] A list of aliases that will be
          transformed from ones having `filename` to ones having `config_setting`.
        default_version: str, the default python version. Defaults to None.
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
            default_version = default_version,
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
    contents["_config/BUILD.bazel"] = _render_pip_config_settings(**flag_versions)
    return contents

def multiplatform_whl_aliases(*, aliases, default_version = None, **kwargs):
    """convert a list of aliases from filename to config_setting ones.

    Args:
        aliases: list(whl_alias): The aliases to process. Any aliases that have
            the filename set will be converted to a list of aliases, each with
            an appropriate config_setting value.
        default_version: string | None, the default python version to use.
        **kwargs: Extra parameters passed to get_filename_config_settings.

    Returns:
        A dict with aliases to be used in the hub repo.
    """

    ret = []
    versioned_additions = {}
    for alias in aliases:
        if not alias.filename:
            ret.append(alias)
            continue

        config_settings, all_versioned_settings = get_filename_config_settings(
            # TODO @aignas 2024-05-27: pass the parsed whl to reduce the
            # number of duplicate operations.
            filename = alias.filename,
            target_platforms = alias.target_platforms,
            python_version = alias.version,
            python_default = default_version == alias.version,
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

def _render_pip_config_settings(python_versions = [], target_platforms = [], osx_versions = [], glibc_versions = [], muslc_versions = []):
    return """\
load("@rules_python//python/private:pip_config_settings.bzl", "pip_config_settings")

pip_config_settings(
    name = "pip_config_settings",
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

        if not a.filename:
            continue

        if a.filename.endswith(".whl") and not a.filename.endswith("-any.whl"):
            parsed = parse_whl_name(a.filename)
        else:
            for plat in a.target_platforms or []:
                target_platforms[plat] = None
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

def get_filename_config_settings(
        *,
        filename,
        target_platforms,
        glibc_versions,
        muslc_versions,
        osx_versions,
        python_version = "",
        python_default = True):
    """Get the filename config settings.

    Args:
        filename: the distribution filename (can be a whl or an sdist).
        target_platforms: list[str], target platforms in "{os}_{cpu}" format.
        glibc_versions: list[tuple[int, int]], list of versions.
        muslc_versions: list[tuple[int, int]], list of versions.
        osx_versions: list[tuple[int, int]], list of versions.
        python_version: the python version to generate the config_settings for.
        python_default: if we should include the setting when python_version is not set.

    Returns:
        A tuple:
         * A list of config settings that are generated by ./pip_config_settings.bzl
         * The list of default version settings.
    """
    prefixes = []
    suffixes = []
    if (0, 0) in glibc_versions:
        fail("Invalid version in 'glibc_versions': cannot specify (0, 0) as a value")
    if (0, 0) in muslc_versions:
        fail("Invalid version in 'muslc_versions': cannot specify (0, 0) as a value")
    if (0, 0) in osx_versions:
        fail("Invalid version in 'osx_versions': cannot specify (0, 0) as a value")

    glibc_versions = sorted(glibc_versions)
    muslc_versions = sorted(muslc_versions)
    osx_versions = sorted(osx_versions)
    setting_supported_versions = {}

    if filename.endswith(".whl"):
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
            prefixes = ["{}_{}_any".format(py, abi)]
            suffixes = target_platforms
        else:
            prefixes = ["{}_{}".format(py, abi)]
            suffixes = _whl_config_setting_suffixes(
                platform_tag = parsed.platform_tag,
                glibc_versions = glibc_versions,
                muslc_versions = muslc_versions,
                osx_versions = osx_versions,
                setting_supported_versions = setting_supported_versions,
            )
    else:
        prefixes = ["sdist"]
        suffixes = target_platforms

    if python_default and python_version:
        prefixes += ["cp{}_{}".format(python_version, p) for p in prefixes]
    elif python_version:
        prefixes = ["cp{}_{}".format(python_version, p) for p in prefixes]
    elif python_default:
        pass
    else:
        fail("BUG: got no python_version and it is not default")

    versioned = {
        ":is_{}_{}".format(p, suffix): {
            version: ":is_{}_{}".format(p, setting)
            for version, setting in versions.items()
        }
        for p in prefixes
        for suffix, versions in setting_supported_versions.items()
    }

    if suffixes or versioned:
        return [":is_{}_{}".format(p, s) for p in prefixes for s in suffixes], versioned
    else:
        return [":is_{}".format(p) for p in prefixes], setting_supported_versions

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
