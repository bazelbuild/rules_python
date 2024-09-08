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
load("//python/private:python.bzl", _parse_modules = "parse_modules")  # buildifier: disable=bzl-visibility

_tests = []

def parse_modules(*, mctx, **kwargs):
    return _parse_modules(module_ctx = mctx, **kwargs)

def _mock_mctx(*modules, environ = {}):
    return struct(
        os = struct(environ = environ),
        modules = [
            struct(
                name = modules[0].name,
                tags = modules[0].tags,
                is_root = modules[0].is_root,
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

def _mod(*, name, toolchain = [], rules_python_private_testing = [], is_root = True):
    return struct(
        name = name,
        tags = struct(
            toolchain = toolchain,
            rules_python_private_testing = rules_python_private_testing,
        ),
        is_root = is_root,
    )

def _toolchain(python_version, *, is_default = False, **kwargs):
    return struct(
        is_default = is_default,
        python_version = python_version,
        **kwargs
    )

def _test_default(env):
    py = parse_modules(
        mctx = _mock_mctx(
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_collection(py.defaults.keys()).contains_exactly([
        "ignore_root_user_error",
    ])
    env.expect.that_bool(py.defaults["ignore_root_user_error"]).equals(False)
    env.expect.that_str(py.default_python_version).equals("3.11")

    want_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([want_toolchain])

_tests.append(_test_default)

def _test_default_some_module(env):
    py = parse_modules(
        mctx = _mock_mctx(
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")], is_root = False),
        ),
    )

    env.expect.that_collection(py.defaults.keys()).contains_exactly([
        "ignore_root_user_error",
    ])
    env.expect.that_str(py.default_python_version).equals("3.11")

    want_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([want_toolchain])

_tests.append(_test_default_some_module)

def _test_default_with_patch_version(env):
    py = parse_modules(
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

_tests.append(_test_default_with_patch_version)

def _test_default_non_rules_python(env):
    py = parse_modules(
        mctx = _mock_mctx(
            # NOTE @aignas 2024-09-06: the first item in the module_ctx.modules
            # could be a non-root module, which is the case if the root module
            # does not make any calls to the extension.
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")], is_root = False),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.11")
    rules_python_toolchain = struct(
        name = "python_3_11",
        python_version = "3.11",
        register_coverage_tool = False,
    )
    env.expect.that_collection(py.toolchains).contains_exactly([rules_python_toolchain])

_tests.append(_test_default_non_rules_python)

def _test_default_non_rules_python_ignore_root_user_error(env):
    py = parse_modules(
        mctx = _mock_mctx(
            _mod(
                name = "my_module",
                toolchain = [_toolchain("3.12", ignore_root_user_error = True)],
            ),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_bool(py.defaults["ignore_root_user_error"]).equals(True)
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

def _test_default_non_rules_python_ignore_root_user_error_non_root_module(env):
    py = parse_modules(
        mctx = _mock_mctx(
            _mod(name = "my_module", toolchain = [_toolchain("3.13")]),
            _mod(name = "some_module", toolchain = [_toolchain("3.12", ignore_root_user_error = True)]),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.13")
    env.expect.that_bool(py.defaults["ignore_root_user_error"]).equals(False)

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
    py = parse_modules(
        mctx = _mock_mctx(
            _mod(name = "my_module", toolchain = [_toolchain("3.12")]),
            _mod(name = "some_module", toolchain = [_toolchain("3.12", configure_coverage_tool = True)]),
            _mod(name = "rules_python", toolchain = [_toolchain("3.11")]),
            environ = {
                "RULES_PYTHON_BZLMOD_DEBUG": "1",
            },
        ),
    )

    env.expect.that_str(py.default_python_version).equals("3.12")

    my_module_toolchain = struct(
        name = "python_3_12",
        python_version = "3.12",
        # NOTE: coverage stays disabled even though `some_module` was
        # configuring something else.
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
    env.expect.that_dict(py.debug_info).contains_exactly({
        "toolchains_registered": [
            {"ignore_root_user_error": False, "name": "python_3_12"},
            {"ignore_root_user_error": False, "name": "python_3_11"},
        ],
    })

_tests.append(_test_first_occurance_of_the_toolchain_wins)

def python_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
