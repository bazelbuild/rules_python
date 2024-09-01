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
load("//python/private:python.bzl", "parse_mods")  # buildifier: disable=bzl-visibility

_tests = []

def _mock_mctx(root_module, *modules):
    return struct(
        os = struct(environ = {}),
        modules = [
            struct(
                name = root_module.name,
                tags = root_module.tags,
                is_root = True,
            ),
        ] + [
            struct(
                name = mod.name,
                tags = mod.tags,
                is_root = False,
            )
            for mod in modules
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

def _test_default(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "rules_python",
                toolchain = [_toolchain("3.11")],
            ),
        ),
        logger = None,
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
    env.expect.that_str(py.default_toolchain.python_version).equals("3.11")
    want_toolchain = struct(
        module = struct(is_root = True, name = "rules_python"),
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )

    env.expect.that_collection(py.toolchains).contains_exactly([want_toolchain])
    env.expect.that_dict(py.global_toolchain_versions).contains_exactly({
        want_toolchain.python_version: want_toolchain,
    })

_tests.append(_test_default)

def _test_default_with_patch(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "rules_python",
                toolchain = [_toolchain("3.11.2")],
            ),
        ),
        logger = None,
    )

    env.expect.that_str(py.default_toolchain.python_version).equals("3.11.2")
    want_toolchain = struct(
        module = struct(is_root = True, name = "rules_python"),
        name = "python_3_11_2",
        python_version = "3.11.2",
        register_coverage_tool = False,
    )

    env.expect.that_collection(py.toolchains).contains_exactly([want_toolchain])
    env.expect.that_dict(py.global_toolchain_versions).contains_exactly({
        want_toolchain.python_version: want_toolchain,
    })

_tests.append(_test_default_with_patch)

def _test_default_non_rules_python(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.12")],
            ),
            _mod(
                name = "rules_python",
                toolchain = [_toolchain("3.11")],
            ),
        ),
        logger = None,
    )

    env.expect.that_str(py.default_toolchain.python_version).equals("3.12")
    my_module_toolchain = struct(
        module = struct(is_root = True, name = "my_module"),
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        module = struct(is_root = False, name = "rules_python"),
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )

    env.expect.that_collection(py.toolchains).contains_exactly([rules_python_toolchain, my_module_toolchain])
    env.expect.that_dict(py.global_toolchain_versions).contains_exactly({
        my_module_toolchain.python_version: my_module_toolchain,
        rules_python_toolchain.python_version: rules_python_toolchain,
    })

_tests.append(_test_default_non_rules_python)

def _test_default_non_rules_python_ignore_root_user_error(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.12", ignore_root_user_error = True)],
            ),
            _mod(
                name = "rules_python",
                toolchain = [_toolchain("3.11")],
            ),
        ),
        logger = None,
    )

    env.expect.that_bool(py.overrides.default["ignore_root_user_error"]).equals(True)
    env.expect.that_str(py.default_toolchain.python_version).equals("3.12")
    my_module_toolchain = struct(
        module = struct(is_root = True, name = "my_module"),
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        module = struct(is_root = False, name = "rules_python"),
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )

    env.expect.that_collection(py.toolchains).contains_exactly([rules_python_toolchain, my_module_toolchain])
    env.expect.that_dict(py.global_toolchain_versions).contains_exactly({
        my_module_toolchain.python_version: my_module_toolchain,
        rules_python_toolchain.python_version: rules_python_toolchain,
    })

_tests.append(_test_default_non_rules_python_ignore_root_user_error)

def _test_default_non_rules_python_ignore_root_user_error_non_root_module(env):
    py = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.13")],
            ),
            _mod(
                name = "some_module",
                toolchain = [_toolchain("3.12", ignore_root_user_error = True)],
            ),
            _mod(
                name = "rules_python",
                toolchain = [_toolchain("3.11")],
            ),
        ),
        logger = None,
    )

    env.expect.that_str(py.default_toolchain.python_version).equals("3.13")
    env.expect.that_bool(py.overrides.default["ignore_root_user_error"]).equals(False)
    my_module_toolchain = struct(
        module = struct(is_root = True, name = "my_module"),
        name = "python_3_13",
        python_version = "3.13",
        register_coverage_tool = False,
    )
    some_module_toolchain = struct(
        module = struct(is_root = False, name = "some_module"),
        name = "python_3_12",
        python_version = "3.12",
        register_coverage_tool = False,
    )
    rules_python_toolchain = struct(
        module = struct(is_root = False, name = "rules_python"),
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )

    env.expect.that_collection(py.toolchains).contains_exactly([rules_python_toolchain, my_module_toolchain, some_module_toolchain])
    env.expect.that_dict(py.global_toolchain_versions).contains_exactly({
        my_module_toolchain.python_version: my_module_toolchain,
        some_module_toolchain.python_version: some_module_toolchain,
        rules_python_toolchain.python_version: rules_python_toolchain,
    })

_tests.append(_test_default_non_rules_python_ignore_root_user_error_non_root_module)

def python_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
