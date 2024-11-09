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

"""render_pkg_aliases tests"""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility
load("//python/private/pypi:config_settings.bzl", "config_settings")  # buildifier: disable=bzl-visibility
load(
    "//python/private/pypi:render_pkg_aliases.bzl",
    "get_filename_config_settings",
    "get_whl_flag_versions",
    "multiplatform_whl_aliases",
    "render_multiplatform_pkg_aliases",
    "render_pkg_aliases",
    "whl_alias",
)  # buildifier: disable=bzl-visibility

def _normalize_label_strings(want):
    """normalize expected strings.

    This function ensures that the desired `render_pkg_aliases` outputs are
    normalized from `bzlmod` to `WORKSPACE` values so that we don't have to
    have to sets of expected strings. The main difference is that under
    `bzlmod` the `str(Label("//my_label"))` results in `"@@//my_label"` whereas
    under `non-bzlmod` we have `"@//my_label"`. This function does
    `string.replace("@@", "@")` to normalize the strings.

    NOTE, in tests, we should only use keep `@@` usage in expectation values
    for the test cases where the whl_alias has the `config_setting` constructed
    from a `Label` instance.
    """
    if "@@" not in want:
        fail("The expected string does not have '@@' labels, consider not using the function")

    if BZLMOD_ENABLED:
        # our expectations are already with double @
        return want

    return want.replace("@@", "@")

_tests = []

def _test_empty(env):
    actual = render_pkg_aliases(
        aliases = None,
    )

    want = {}

    env.expect.that_dict(actual).contains_exactly(want)

_tests.append(_test_empty)

def _test_legacy_aliases(env):
    actual = render_pkg_aliases(
        aliases = {
            "foo": [
                whl_alias(repo = "pypi_foo"),
            ],
        },
    )

    want_key = "foo/BUILD.bazel"
    want_content = """\
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = ["//visibility:public"])

alias(
    name = "foo",
    actual = ":pkg",
)

alias(
    name = "pkg",
    actual = "@pypi_foo//:pkg",
)

alias(
    name = "whl",
    actual = "@pypi_foo//:whl",
)

alias(
    name = "data",
    actual = "@pypi_foo//:data",
)

alias(
    name = "dist_info",
    actual = "@pypi_foo//:dist_info",
)"""

    env.expect.that_dict(actual).contains_exactly({want_key: want_content})

_tests.append(_test_legacy_aliases)

def _test_bzlmod_aliases(env):
    # Use this function as it is used in pip_repository
    actual = render_multiplatform_pkg_aliases(
        aliases = {
            "bar-baz": [
                whl_alias(version = "3.2", repo = "pypi_32_bar_baz", config_setting = "//:my_config_setting"),
            ],
        },
    )

    want_key = "bar_baz/BUILD.bazel"
    want_content = """\
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = ["//visibility:public"])

_NO_MATCH_ERROR = \"\"\"\\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
wheels available for this wheel. This wheel supports the following Python
configuration settings:
    //:my_config_setting

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    rules_python//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
\"\"\"

alias(
    name = "bar_baz",
    actual = ":pkg",
)

alias(
    name = "pkg",
    actual = selects.with_or(
        {
            "//:my_config_setting": "@pypi_32_bar_baz//:pkg",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "whl",
    actual = selects.with_or(
        {
            "//:my_config_setting": "@pypi_32_bar_baz//:whl",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "data",
    actual = selects.with_or(
        {
            "//:my_config_setting": "@pypi_32_bar_baz//:data",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "dist_info",
    actual = selects.with_or(
        {
            "//:my_config_setting": "@pypi_32_bar_baz//:dist_info",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)"""

    env.expect.that_str(actual.pop("_config/BUILD.bazel")).equals(
        """\
load("@rules_python//python/private/pypi:config_settings.bzl", "config_settings")

config_settings(
    name = "config_settings",
    glibc_versions = [],
    muslc_versions = [],
    osx_versions = [],
    python_versions = ["3.2"],
    target_platforms = [],
    visibility = ["//:__subpackages__"],
)""",
    )
    env.expect.that_collection(actual.keys()).contains_exactly([want_key])
    env.expect.that_str(actual[want_key]).equals(want_content)

_tests.append(_test_bzlmod_aliases)

def _test_bzlmod_aliases_with_no_default_version(env):
    actual = render_multiplatform_pkg_aliases(
        aliases = {
            "bar-baz": [
                whl_alias(
                    version = "3.2",
                    repo = "pypi_32_bar_baz",
                    # pass the label to ensure that it gets converted to string
                    config_setting = Label("//python/config_settings:is_python_3.2"),
                ),
                whl_alias(version = "3.1", repo = "pypi_31_bar_baz"),
            ],
        },
    )

    want_key = "bar_baz/BUILD.bazel"
    want_content = """\
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = ["//visibility:public"])

_NO_MATCH_ERROR = \"\"\"\\
No matching wheel for current configuration's Python version.

The current build configuration's Python version doesn't match any of the Python
wheels available for this wheel. This wheel supports the following Python
configuration settings:
    //_config:is_python_3.1
    @@//python/config_settings:is_python_3.2

To determine the current configuration's Python version, run:
    `bazel config <config id>` (shown further below)
and look for
    rules_python//python/config_settings:python_version

If the value is missing, then the "default" Python version is being used,
which has a "null" version value and will not match version constraints.
\"\"\"

alias(
    name = "bar_baz",
    actual = ":pkg",
)

alias(
    name = "pkg",
    actual = selects.with_or(
        {
            "//_config:is_python_3.1": "@pypi_31_bar_baz//:pkg",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:pkg",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "whl",
    actual = selects.with_or(
        {
            "//_config:is_python_3.1": "@pypi_31_bar_baz//:whl",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:whl",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "data",
    actual = selects.with_or(
        {
            "//_config:is_python_3.1": "@pypi_31_bar_baz//:data",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:data",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)

alias(
    name = "dist_info",
    actual = selects.with_or(
        {
            "//_config:is_python_3.1": "@pypi_31_bar_baz//:dist_info",
            "@@//python/config_settings:is_python_3.2": "@pypi_32_bar_baz//:dist_info",
        },
        no_match_error = _NO_MATCH_ERROR,
    ),
)"""

    actual.pop("_config/BUILD.bazel")
    env.expect.that_collection(actual.keys()).contains_exactly([want_key])
    env.expect.that_str(actual[want_key]).equals(_normalize_label_strings(want_content))

_tests.append(_test_bzlmod_aliases_with_no_default_version)

def _test_aliases_are_created_for_all_wheels(env):
    actual = render_pkg_aliases(
        aliases = {
            "bar": [
                whl_alias(version = "3.1", repo = "pypi_31_bar"),
                whl_alias(version = "3.2", repo = "pypi_32_bar"),
            ],
            "foo": [
                whl_alias(version = "3.1", repo = "pypi_32_foo"),
                whl_alias(version = "3.2", repo = "pypi_31_foo"),
            ],
        },
    )

    want_files = [
        "bar/BUILD.bazel",
        "foo/BUILD.bazel",
    ]

    env.expect.that_dict(actual).keys().contains_exactly(want_files)

_tests.append(_test_aliases_are_created_for_all_wheels)

def _test_aliases_with_groups(env):
    actual = render_pkg_aliases(
        aliases = {
            "bar": [
                whl_alias(version = "3.1", repo = "pypi_31_bar"),
                whl_alias(version = "3.2", repo = "pypi_32_bar"),
            ],
            "baz": [
                whl_alias(version = "3.1", repo = "pypi_31_baz"),
                whl_alias(version = "3.2", repo = "pypi_32_baz"),
            ],
            "foo": [
                whl_alias(version = "3.1", repo = "pypi_32_foo"),
                whl_alias(version = "3.2", repo = "pypi_31_foo"),
            ],
        },
        requirement_cycles = {
            "group": ["bar", "baz"],
        },
    )

    want_files = [
        "bar/BUILD.bazel",
        "foo/BUILD.bazel",
        "baz/BUILD.bazel",
        "_groups/BUILD.bazel",
    ]
    env.expect.that_dict(actual).keys().contains_exactly(want_files)

    want_key = "_groups/BUILD.bazel"

    # Just check that it contains a private whl
    env.expect.that_str(actual[want_key]).contains("//bar:_whl")

    want_key = "bar/BUILD.bazel"

    # Just check that it contains a private whl
    env.expect.that_str(actual[want_key]).contains("name = \"_whl\"")
    env.expect.that_str(actual[want_key]).contains("name = \"whl\"")
    env.expect.that_str(actual[want_key]).contains("\"//_groups:group_whl\"")

_tests.append(_test_aliases_with_groups)

def _test_empty_flag_versions(env):
    got = get_whl_flag_versions(
        aliases = [],
    )
    want = {}
    env.expect.that_dict(got).contains_exactly(want)

_tests.append(_test_empty_flag_versions)

def _test_get_python_versions(env):
    got = get_whl_flag_versions(
        aliases = [
            whl_alias(repo = "foo", version = "3.3"),
            whl_alias(repo = "foo", version = "3.2"),
        ],
    )
    want = {
        "python_versions": ["3.2", "3.3"],
    }
    env.expect.that_dict(got).contains_exactly(want)

_tests.append(_test_get_python_versions)

def _test_get_python_versions_with_target_platforms(env):
    got = get_whl_flag_versions(
        aliases = [
            whl_alias(repo = "foo", version = "3.3", target_platforms = ["cp33_linux_x86_64"]),
            whl_alias(repo = "foo", version = "3.2", target_platforms = ["cp32_linux_x86_64", "cp32_osx_aarch64"]),
        ],
    )
    want = {
        "python_versions": ["3.2", "3.3"],
        "target_platforms": [
            "linux_x86_64",
            "osx_aarch64",
        ],
    }
    env.expect.that_dict(got).contains_exactly(want)

_tests.append(_test_get_python_versions_with_target_platforms)

def _test_get_python_versions_from_filenames(env):
    got = get_whl_flag_versions(
        aliases = [
            whl_alias(
                repo = "foo",
                version = "3.3",
                filename = "foo-0.0.0-py3-none-" + plat + ".whl",
            )
            for plat in [
                "linux_x86_64",
                "manylinux_2_17_x86_64",
                "manylinux_2_14_aarch64.musllinux_1_1_aarch64",
                "musllinux_1_0_x86_64",
                "manylinux2014_x86_64.manylinux_2_17_x86_64",
                "macosx_11_0_arm64",
                "macosx_10_9_x86_64",
                "macosx_10_9_universal2",
                "windows_x86_64",
            ]
        ],
    )
    want = {
        "glibc_versions": [(2, 14), (2, 17)],
        "muslc_versions": [(1, 0), (1, 1)],
        "osx_versions": [(10, 9), (11, 0)],
        "python_versions": ["3.3"],
        "target_platforms": [
            "linux_aarch64",
            "linux_x86_64",
            "osx_aarch64",
            "osx_x86_64",
            "windows_x86_64",
        ],
    }
    env.expect.that_dict(got).contains_exactly(want)

_tests.append(_test_get_python_versions_from_filenames)

def _test_get_flag_versions_from_alias_target_platforms(env):
    got = get_whl_flag_versions(
        aliases = [
            whl_alias(
                repo = "foo",
                version = "3.3",
                filename = "foo-0.0.0-py3-none-" + plat + ".whl",
            )
            for plat in [
                "windows_x86_64",
            ]
        ] + [
            whl_alias(
                repo = "foo",
                version = "3.3",
                filename = "foo-0.0.0-py3-none-any.whl",
                target_platforms = [
                    "cp33_linux_x86_64",
                ],
            ),
        ],
    )
    want = {
        "python_versions": ["3.3"],
        "target_platforms": [
            "linux_x86_64",
            "windows_x86_64",
        ],
    }
    env.expect.that_dict(got).contains_exactly(want)

_tests.append(_test_get_flag_versions_from_alias_target_platforms)

def _test_config_settings(
        env,
        *,
        filename,
        want,
        python_version,
        want_versions = {},
        target_platforms = [],
        glibc_versions = [],
        muslc_versions = [],
        osx_versions = []):
    got, got_default_version_settings = get_filename_config_settings(
        filename = filename,
        target_platforms = target_platforms,
        glibc_versions = glibc_versions,
        muslc_versions = muslc_versions,
        osx_versions = osx_versions,
        python_version = python_version,
    )
    env.expect.that_collection(got).contains_exactly(want)
    env.expect.that_dict(got_default_version_settings).contains_exactly(want_versions)

def _test_sdist(env):
    # Do the first test for multiple extensions
    for ext in [".tar.gz", ".zip"]:
        _test_config_settings(
            env,
            filename = "foo-0.0.1" + ext,
            python_version = "3.2",
            want = [":is_cp3.2_sdist"],
        )

    ext = ".zip"
    _test_config_settings(
        env,
        filename = "foo-0.0.1" + ext,
        python_version = "3.2",
        target_platforms = [
            "linux_aarch64",
            "linux_x86_64",
        ],
        want = [
            ":is_cp3.2_sdist_linux_aarch64",
            ":is_cp3.2_sdist_linux_x86_64",
        ],
    )

_tests.append(_test_sdist)

def _test_py2_py3_none_any(env):
    _test_config_settings(
        env,
        filename = "foo-0.0.1-py2.py3-none-any.whl",
        python_version = "3.2",
        want = [
            ":is_cp3.2_py_none_any",
        ],
    )

    _test_config_settings(
        env,
        filename = "foo-0.0.1-py2.py3-none-any.whl",
        python_version = "3.2",
        target_platforms = [
            "osx_x86_64",
        ],
        want = [":is_cp3.2_py_none_any_osx_x86_64"],
    )

_tests.append(_test_py2_py3_none_any)

def _test_py3_none_any(env):
    _test_config_settings(
        env,
        filename = "foo-0.0.1-py3-none-any.whl",
        python_version = "3.1",
        want = [":is_cp3.1_py3_none_any"],
    )

    _test_config_settings(
        env,
        filename = "foo-0.0.1-py3-none-any.whl",
        python_version = "3.1",
        target_platforms = ["linux_x86_64"],
        want = [":is_cp3.1_py3_none_any_linux_x86_64"],
    )

_tests.append(_test_py3_none_any)

def _test_py3_none_macosx_10_9_universal2(env):
    _test_config_settings(
        env,
        filename = "foo-0.0.1-py3-none-macosx_10_9_universal2.whl",
        python_version = "3.1",
        osx_versions = [
            (10, 9),
            (11, 0),
        ],
        want = [],
        want_versions = {
            ":is_cp3.1_py3_none_osx_aarch64_universal2": {
                (10, 9): ":is_cp3.1_py3_none_osx_10_9_aarch64_universal2",
                (11, 0): ":is_cp3.1_py3_none_osx_11_0_aarch64_universal2",
            },
            ":is_cp3.1_py3_none_osx_x86_64_universal2": {
                (10, 9): ":is_cp3.1_py3_none_osx_10_9_x86_64_universal2",
                (11, 0): ":is_cp3.1_py3_none_osx_11_0_x86_64_universal2",
            },
        },
    )

_tests.append(_test_py3_none_macosx_10_9_universal2)

def _test_cp37_abi3_linux_x86_64(env):
    _test_config_settings(
        env,
        filename = "foo-0.0.1-cp37-abi3-linux_x86_64.whl",
        python_version = "3.7",
        want = [":is_cp3.7_cp3x_abi3_linux_x86_64"],
    )

_tests.append(_test_cp37_abi3_linux_x86_64)

def _test_cp37_abi3_windows_x86_64(env):
    _test_config_settings(
        env,
        filename = "foo-0.0.1-cp37-abi3-windows_x86_64.whl",
        python_version = "3.7",
        want = [":is_cp3.7_cp3x_abi3_windows_x86_64"],
    )

_tests.append(_test_cp37_abi3_windows_x86_64)

def _test_cp37_abi3_manylinux_2_17_x86_64(env):
    _test_config_settings(
        env,
        filename = "foo-0.0.1-cp37-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl",
        python_version = "3.7",
        glibc_versions = [
            (2, 16),
            (2, 17),
            (2, 18),
        ],
        want = [],
        want_versions = {
            ":is_cp3.7_cp3x_abi3_manylinux_x86_64": {
                (2, 17): ":is_cp3.7_cp3x_abi3_manylinux_2_17_x86_64",
                (2, 18): ":is_cp3.7_cp3x_abi3_manylinux_2_18_x86_64",
            },
        },
    )

_tests.append(_test_cp37_abi3_manylinux_2_17_x86_64)

def _test_cp37_abi3_manylinux_2_17_musllinux_1_1_aarch64(env):
    # I've seen such a wheel being built for `uv`
    _test_config_settings(
        env,
        filename = "foo-0.0.1-cp37-cp37-manylinux_2_17_arm64.musllinux_1_1_arm64.whl",
        python_version = "3.7",
        glibc_versions = [
            (2, 16),
            (2, 17),
            (2, 18),
        ],
        muslc_versions = [
            (1, 1),
        ],
        want = [],
        want_versions = {
            ":is_cp3.7_cp3x_cp_manylinux_aarch64": {
                (2, 17): ":is_cp3.7_cp3x_cp_manylinux_2_17_aarch64",
                (2, 18): ":is_cp3.7_cp3x_cp_manylinux_2_18_aarch64",
            },
            ":is_cp3.7_cp3x_cp_musllinux_aarch64": {
                (1, 1): ":is_cp3.7_cp3x_cp_musllinux_1_1_aarch64",
            },
        },
    )

_tests.append(_test_cp37_abi3_manylinux_2_17_musllinux_1_1_aarch64)

def _test_multiplatform_whl_aliases_empty(env):
    # Check that we still work with an empty requirements.txt
    got = multiplatform_whl_aliases(aliases = [])
    env.expect.that_collection(got).contains_exactly([])

_tests.append(_test_multiplatform_whl_aliases_empty)

def _test_multiplatform_whl_aliases_nofilename(env):
    aliases = [
        whl_alias(
            repo = "foo",
            config_setting = "//:label",
            version = "3.1",
        ),
    ]
    got = multiplatform_whl_aliases(aliases = aliases)
    env.expect.that_collection(got).contains_exactly(aliases)

_tests.append(_test_multiplatform_whl_aliases_nofilename)

def _test_multiplatform_whl_aliases_nofilename_target_platforms(env):
    aliases = [
        whl_alias(
            repo = "foo",
            config_setting = "//:ignored",
            version = "3.1",
            target_platforms = [
                "cp31_linux_x86_64",
                "cp31_linux_aarch64",
            ],
        ),
    ]

    got = multiplatform_whl_aliases(aliases = aliases)

    want = [
        whl_alias(config_setting = "//_config:is_cp3.1_linux_x86_64", repo = "foo", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_linux_aarch64", repo = "foo", version = "3.1"),
    ]
    env.expect.that_collection(got).contains_exactly(want)

_tests.append(_test_multiplatform_whl_aliases_nofilename_target_platforms)

def _test_multiplatform_whl_aliases_filename(env):
    aliases = [
        whl_alias(
            repo = "foo-py3-0.0.3",
            filename = "foo-0.0.3-py3-none-any.whl",
            version = "3.2",
        ),
        whl_alias(
            repo = "foo-py3-0.0.1",
            filename = "foo-0.0.1-py3-none-any.whl",
            version = "3.1",
        ),
        whl_alias(
            repo = "foo-0.0.2",
            filename = "foo-0.0.2-py3-none-any.whl",
            version = "3.1",
            target_platforms = [
                "cp31_linux_x86_64",
                "cp31_linux_aarch64",
            ],
        ),
    ]
    got = multiplatform_whl_aliases(
        aliases = aliases,
        glibc_versions = [],
        muslc_versions = [],
        osx_versions = [],
    )
    want = [
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_any", repo = "foo-py3-0.0.1", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_any_linux_aarch64", repo = "foo-0.0.2", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_any_linux_x86_64", repo = "foo-0.0.2", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.2_py3_none_any", repo = "foo-py3-0.0.3", version = "3.2"),
    ]
    env.expect.that_collection(got).contains_exactly(want)

_tests.append(_test_multiplatform_whl_aliases_filename)

def _test_multiplatform_whl_aliases_filename_versioned(env):
    aliases = [
        whl_alias(
            repo = "glibc-2.17",
            filename = "foo-0.0.1-py3-none-manylinux_2_17_x86_64.whl",
            version = "3.1",
        ),
        whl_alias(
            repo = "glibc-2.18",
            filename = "foo-0.0.1-py3-none-manylinux_2_18_x86_64.whl",
            version = "3.1",
        ),
        whl_alias(
            repo = "musl",
            filename = "foo-0.0.1-py3-none-musllinux_1_1_x86_64.whl",
            version = "3.1",
        ),
    ]
    got = multiplatform_whl_aliases(
        aliases = aliases,
        glibc_versions = [(2, 17), (2, 18)],
        muslc_versions = [(1, 1), (1, 2)],
        osx_versions = [],
    )
    want = [
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_manylinux_2_17_x86_64", repo = "glibc-2.17", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_manylinux_2_18_x86_64", repo = "glibc-2.18", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_manylinux_x86_64", repo = "glibc-2.17", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_musllinux_1_1_x86_64", repo = "musl", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_musllinux_1_2_x86_64", repo = "musl", version = "3.1"),
        whl_alias(config_setting = "//_config:is_cp3.1_py3_none_musllinux_x86_64", repo = "musl", version = "3.1"),
    ]
    env.expect.that_collection(got).contains_exactly(want)

_tests.append(_test_multiplatform_whl_aliases_filename_versioned)

def _mock_alias(container):
    return lambda name, **kwargs: container.append(name)

def _mock_config_setting(container):
    def _inner(name, flag_values = None, constraint_values = None, **_):
        if flag_values or constraint_values:
            container.append(name)
            return

        fail("At least one of 'flag_values' or 'constraint_values' needs to be set")

    return _inner

def _test_config_settings_exist_legacy(env):
    aliases = [
        whl_alias(
            repo = "repo",
            version = "3.11",
            target_platforms = [
                "cp311_linux_aarch64",
                "cp311_linux_x86_64",
            ],
        ),
    ]
    available_config_settings = []
    config_settings(
        python_versions = ["3.11"],
        native = struct(
            alias = _mock_alias(available_config_settings),
            config_setting = _mock_config_setting(available_config_settings),
        ),
        target_platforms = [
            "linux_aarch64",
            "linux_x86_64",
        ],
    )

    got_aliases = multiplatform_whl_aliases(
        aliases = aliases,
    )
    got = [a.config_setting.partition(":")[-1] for a in got_aliases]

    env.expect.that_collection(available_config_settings).contains_at_least(got)

_tests.append(_test_config_settings_exist_legacy)

def _test_config_settings_exist(env):
    for py_tag in ["py2.py3", "py3", "py311", "cp311"]:
        if py_tag == "py2.py3":
            abis = ["none"]
        elif py_tag.startswith("py"):
            abis = ["none", "abi3"]
        else:
            abis = ["none", "abi3", "cp311"]

        for abi_tag in abis:
            for platform_tag, kwargs in {
                "any": {},
                "macosx_11_0_arm64": {
                    "osx_versions": [(11, 0)],
                    "target_platforms": ["osx_aarch64"],
                },
                "manylinux_2_17_x86_64": {
                    "glibc_versions": [(2, 17), (2, 18)],
                    "target_platforms": ["linux_x86_64"],
                },
                "manylinux_2_18_x86_64": {
                    "glibc_versions": [(2, 17), (2, 18)],
                    "target_platforms": ["linux_x86_64"],
                },
                "musllinux_1_1_aarch64": {
                    "muslc_versions": [(1, 2), (1, 1), (1, 0)],
                    "target_platforms": ["linux_aarch64"],
                },
            }.items():
                aliases = [
                    whl_alias(
                        repo = "repo",
                        filename = "foo-0.0.1-{}-{}-{}.whl".format(py_tag, abi_tag, platform_tag),
                        version = "3.11",
                    ),
                ]
                available_config_settings = []
                config_settings(
                    python_versions = ["3.11"],
                    native = struct(
                        alias = _mock_alias(available_config_settings),
                        config_setting = _mock_config_setting(available_config_settings),
                    ),
                    **kwargs
                )

                got_aliases = multiplatform_whl_aliases(
                    aliases = aliases,
                    glibc_versions = kwargs.get("glibc_versions", []),
                    muslc_versions = kwargs.get("muslc_versions", []),
                    osx_versions = kwargs.get("osx_versions", []),
                )
                got = [a.config_setting.partition(":")[-1] for a in got_aliases]

                env.expect.that_collection(available_config_settings).contains_at_least(got)

_tests.append(_test_config_settings_exist)

def render_pkg_aliases_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
