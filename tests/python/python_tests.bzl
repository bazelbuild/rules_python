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

""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/private:python.bzl", _parse_mods = "parse_mods")  # buildifier: disable=bzl-visibility

_tests = []

def parse_mods(*, mctx, **kwargs):
    return _parse_mods(mctx = mctx, logger = None, **kwargs)

def _mock_mctx(*modules, environ = {}):
    return struct(
        os = struct(environ = environ),
        modules = [
            struct(
                name = modules[0].name,
                tags = modules[0].tags,
                is_root = True,
            ),
        ] + [
            struct(
                name = mod.name,
                tags = mod.tags,
                is_root = False,
            )
            for mod in modules[1:]
        ],
    )

def _mod(*, name, toolchain = [], override = [], single_version_override = [], single_version_platform_override = []):
    return struct(
        name = name,
        tags = struct(
            toolchain = toolchain,
            override = override,
            single_version_override = single_version_override,
            single_version_platform_override = single_version_platform_override,
        ),
    )

def _toolchain(python_version, *, is_default = False, **kwargs):
    return struct(
        is_default = is_default,
        python_version = python_version,
        **kwargs
    )

def _override(
        auth_patterns = {},
        available_python_versions = [],
        base_url = "",
        ignore_root_user_error = False,
        minor_mapping = {},
        netrc = "",
        register_all_versions = False):
    return struct(
        auth_patterns = auth_patterns,
        available_python_versions = available_python_versions,
        base_url = base_url,
        ignore_root_user_error = ignore_root_user_error,
        minor_mapping = minor_mapping,
        netrc = netrc,
        register_all_versions = register_all_versions,
    )

def _single_version_override(
        **kwargs):
    return struct(
        **kwargs
    )

def _single_version_platform_override(
        **kwargs):
    return struct(
        **kwargs
    )

def _test_default(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_collection(py.overrides.minor_mapping.keys()).contains_exactly([
        "3.10",
        "3.11",
        "3.12",
        "3.8",
        "3.9",
    ])
    env.expect.that_collection(py.overrides.kwargs).has_size(0)
    env.expect.that_collection(py.overrides.default.keys()).contains_exactly([
        "base_url",
        "ignore_root_user_error",
        "tool_versions",
    ])
    env.expect.that_bool(py.overrides.default["ignore_root_user_error"]).equals(False)
    env.expect.that_str(py.default_python_version).equals("3.11")

    want_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([want_toolchain])

_tests.append(_test_default)

def _test_default_with_patch(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(name = "rules_python", toolchain = [_toolchain("3.11.2")]),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.11.2")

    want_toolchain = struct(
        name = "python_3_11_2",
        python_version = "3.11.2",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([want_toolchain])

_tests.append(_test_default_with_patch)

def _test_default_non_rules_python(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(name = "my_module", toolchain = [_toolchain("3.12")]),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.12")

    my_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([
        rules_python_toolchain,
        my_module_toolchain,  # default toolchain is last
    ]).in_order()

_tests.append(_test_default_non_rules_python)

def _test_default_non_rules_python_ignore_root_user_error(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.12", ignore_root_user_error = True)],
            ),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_bool(py.overrides.default["ignore_root_user_error"]).equals(True)
    env.expect.that_str(py.default_python_version).equals("3.12")

    my_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([
        rules_python_toolchain,
        my_module_toolchain,
    ]).in_order()

_tests.append(_test_default_non_rules_python_ignore_root_user_error)

def _test_default_non_rules_python_ignore_root_user_error_override(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.12")],
                override = [_override(ignore_root_user_error = True)],
            ),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_bool(py.overrides.default["ignore_root_user_error"]).equals(True)
    env.expect.that_str(py.default_python_version).equals("3.12")

    my_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([
        rules_python_toolchain,
        my_module_toolchain,
    ]).in_order()

_tests.append(_test_default_non_rules_python_ignore_root_user_error_override)

def _test_default_non_rules_python_ignore_root_user_error_non_root_module(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(name = "my_module", toolchain = [_toolchain("3.13")]),
            _mod(name = "some_module", toolchain = [_toolchain("3.12", ignore_root_user_error = True)]),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.13")
    env.expect.that_bool(py.overrides.default["ignore_root_user_error"]).equals(False)

    my_module_toolchain = struct(
        name = "python_3_13",
        python_version = "3.13",
        register_coverage_tool = False,
    )
    some_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([
        some_module_toolchain,
        rules_python_toolchain,
        my_module_toolchain,
    ]).in_order()

_tests.append(_test_default_non_rules_python_ignore_root_user_error_non_root_module)

def _test_first_occurance_of_the_toolchain_wins(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(name = "my_module", toolchain = [_toolchain("3.12")]),
            _mod(name = "some_module", toolchain = [_toolchain("3.12", configure_coverage_tool = True)]),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
        debug = True,
    )

    env.expect.that_str(py.default_python_version).equals("3.12")

    my_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        # NOTE: coverage stays disabled even though `some_module` was
        # configuring something else.
        register_coverage_tool = False,
        debug = {
            "module": struct(is_root = True, name = "my_module"),
        },
    )
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
        debug = {
            "module": struct(is_root = False, name = "rules_python"),
        },
    )
    env.expect.that_collection(py.toolchains).contains_exactly([
        rules_python_toolchain,
        my_module_toolchain,  # default toolchain is last
    ]).in_order()

_tests.append(_test_first_occurance_of_the_toolchain_wins)

def _test_auth_overrides(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.12")],
                override = [
                    _override(
                        netrc = "/my/netrc",
                        auth_patterns = {"foo": "bar"},
                    ),
                ],
            ),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_dict(py.overrides.default).contains_at_least({
        "auth_patterns": {"foo": "bar"},
        "ignore_root_user_error": False,
        "netrc": "/my/netrc",
    })
    env.expect.that_str(py.default_python_version).equals("3.12")

    my_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([
        rules_python_toolchain,
        my_module_toolchain,
    ]).in_order()

_tests.append(_test_auth_overrides)

def _test_add_new_version(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.13")],
                single_version_override = [
                    _single_version_override(
                        python_version = "3.13.0",
                        sha256 = {
                            "aarch64-unknown-linux-gnu": "deadbeef",
                        },
                        urls = ["example.org"],
                        patch_strip = 0,
                        patches = [],
                        strip_prefix = "prefix",
                        distutils_content = "",
                        distutils = None,
                    ),
                ],
                single_version_platform_override = [
                    _single_version_platform_override(
                        sha256 = "deadb00f",
                        urls = ["something.org", "else.org"],
                        strip_prefix = "python",
                        platform = "aarch64-unknown-linux-gnu",
                        coverage_tool = "specific_cov_tool",
                        python_version = "3.13.1",
                        patch_strip = 2,
                        patches = ["specific-patch.txt"],
                    ),
                ],
                override = [
                    _override(
                        base_url = "",
                        available_python_versions = ["3.12.4", "3.13.0", "3.13.1"],
                        minor_mapping = {
                            "3.13": "3.13.0",
                        },
                    ),
                ],
            ),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.13")
    env.expect.that_collection(py.overrides.default["tool_versions"].keys()).contains_exactly([
        "3.12.4",
        "3.13.0",
        "3.13.1",
    ])
    env.expect.that_dict(py.overrides.default["tool_versions"]["3.13.0"]).contains_exactly({
        "sha256": {"aarch64-unknown-linux-gnu": "deadbeef"},
        "strip_prefix": {"aarch64-unknown-linux-gnu": "prefix"},
        "url": {"aarch64-unknown-linux-gnu": ["example.org"]},
    })
    env.expect.that_dict(py.overrides.default["tool_versions"]["3.13.1"]).contains_exactly({
        "coverage_tool": {"aarch64-unknown-linux-gnu": "specific_cov_tool"},
        "patch_strip": {"aarch64-unknown-linux-gnu": 2},
        "patches": {"aarch64-unknown-linux-gnu": ["specific-patch.txt"]},
        "sha256": {"aarch64-unknown-linux-gnu": "deadb00f"},
        "strip_prefix": {"aarch64-unknown-linux-gnu": "python"},
        "url": {"aarch64-unknown-linux-gnu": ["something.org", "else.org"]},
    })
    env.expect.that_dict(py.overrides.minor_mapping).contains_exactly({
        "3.13": "3.13.0",
    })
    env.expect.that_collection(py.toolchains).contains_exactly([
        struct(
            name = "python_3_13",
            python_version = "3.13",
            register_coverage_tool = False,
        ),
    ])

_tests.append(_test_add_new_version)

def _test_add_patches(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.13")],
                single_version_override = [
                    _single_version_override(
                        python_version = "3.13.0",
                        sha256 = {
                            "aarch64-apple-darwin": "deadbeef",
                            "aarch64-unknown-linux-gnu": "deadbeef",
                        },
                        urls = ["example.org"],
                        patch_strip = 1,
                        patches = ["common.txt"],
                        strip_prefix = "prefix",
                        distutils_content = "",
                        distutils = None,
                    ),
                ],
                single_version_platform_override = [
                    _single_version_platform_override(
                        sha256 = "deadb00f",
                        urls = ["something.org", "else.org"],
                        strip_prefix = "python",
                        platform = "aarch64-unknown-linux-gnu",
                        coverage_tool = "specific_cov_tool",
                        python_version = "3.13.0",
                        patch_strip = 2,
                        patches = ["specific-patch.txt"],
                    ),
                ],
                override = [
                    _override(
                        base_url = "",
                        available_python_versions = ["3.13.0"],
                        minor_mapping = {
                            "3.13": "3.13.0",
                        },
                    ),
                ],
            ),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.13")
    env.expect.that_dict(py.overrides.default["tool_versions"]).contains_exactly({
        "3.13.0": {
            "coverage_tool": {"aarch64-unknown-linux-gnu": "specific_cov_tool"},
            "patch_strip": {"aarch64-apple-darwin": 1, "aarch64-unknown-linux-gnu": 2},
            "patches": {
                "aarch64-apple-darwin": ["common.txt"],
                "aarch64-unknown-linux-gnu": ["specific-patch.txt"],
            },
            "sha256": {"aarch64-apple-darwin": "deadbeef", "aarch64-unknown-linux-gnu": "deadb00f"},
            "strip_prefix": {"aarch64-apple-darwin": "prefix", "aarch64-unknown-linux-gnu": "python"},
            "url": {
                "aarch64-apple-darwin": ["example.org"],
                "aarch64-unknown-linux-gnu": ["something.org", "else.org"],
            },
        },
    })
    env.expect.that_dict(py.overrides.minor_mapping).contains_exactly({
        "3.13": "3.13.0",
    })
    env.expect.that_collection(py.toolchains).contains_exactly([
        struct(
            name = "python_3_13",
            python_version = "3.13",
            register_coverage_tool = False,
        ),
    ])

_tests.append(_test_add_patches)

# TODO @aignas 2024-09-03: add failure tests:
# * validate the python_version in overrides
# * incorrect platform failure
# * missing python_version failure

def python_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
