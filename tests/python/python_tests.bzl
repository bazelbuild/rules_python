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
        ] + list(modules),
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

def _toolchain(python_version, *, is_default = False):
    return struct(
        is_default = is_default,
        python_version = python_version,
    )

def test_default(env):
    got = parse_mods(
        mctx = _mock_mctx(
            _mod(
                name = "rules_python",
                toolchain = [_toolchain("3.11")],
            ),
        ),
        logger = None,
    )
    env.expect.that_str(got).equals("prefix_foo_py3_none_any_deadbeef")

_tests.append(_test_simple)

def python_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
