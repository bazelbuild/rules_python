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
load("//python/private/pypi:extension.bzl", "parse_modules")  # buildifier: disable=bzl-visibility
load(":parse_modules_subject.bzl", "parse_modules_subject")

_tests = []

def _mock_mctx(*modules, environ = {}, read = None):
    return struct(
        os = struct(
            environ = environ,
            name = "unittest",
            arch = "exotic",
        ),
        read = read or {}.get,
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

def _mod(*, name, parse = [], override = [], whl_mods = [], is_root = True):
    return struct(
        name = name,
        tags = struct(
            parse = parse,
            override = override,
            whl_mods = whl_mods,
        ),
        is_root = is_root,
    )

def _parse_modules(env, **kwargs):
    return parse_modules_subject(
        parse_modules(**kwargs),
        meta = env.expect.meta,
    )

def _parse(
        *,
        hub_name,
        python_version,
        _evaluate_markers_srcs = [],
        auth_patterns = {},
        download_only = False,
        enable_implicit_namespace_pkgs = False,
        environment = {},
        envsubst = {},
        experimental_index_url = "",
        experimental_requirement_cycles = {},
        experimental_target_platforms = [],
        extra_pip_args = [],
        isolated = False,
        netrc = None,
        pip_data_exclude = None,
        python_interpreter = None,
        python_interpreter_target = None,
        quiet = False,
        requirements_by_platform = {},
        requirements_darwin = None,
        requirements_linux = None,
        requirements_lock = None,
        requirements_windows = None,
        timeout = 42,
        whl_modifications = {},
        **kwargs):
    return struct(
        _evaluate_markers_srcs = _evaluate_markers_srcs,
        auth_patterns = auth_patterns,
        download_only = download_only,
        enable_implicit_namespace_pkgs = enable_implicit_namespace_pkgs,
        environment = environment,
        envsubst = envsubst,
        experimental_index_url = experimental_index_url,
        experimental_requirement_cycles = experimental_requirement_cycles,
        experimental_target_platforms = experimental_target_platforms,
        extra_pip_args = extra_pip_args,
        hub_name = hub_name,
        isolated = isolated,
        netrc = netrc,
        pip_data_exclude = pip_data_exclude,
        python_interpreter = python_interpreter,
        python_interpreter_target = python_interpreter_target,
        python_version = python_version,
        quiet = quiet,
        requirements_by_platform = requirements_by_platform,
        requirements_darwin = requirements_darwin,
        requirements_linux = requirements_linux,
        requirements_lock = requirements_lock,
        requirements_windows = requirements_windows,
        timeout = timeout,
        whl_modifications = whl_modifications,
        **kwargs
    )

def _test_simple(env):
    pypi = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(name = "rules_python", parse = [_parse(
                hub_name = "pypi",
                python_version = "3.15",
                requirements_lock = "requirements.txt",
            )]),
            read = {
                "requirements.txt": "",
            }.get,
        ),
        available_interpreters = {
            "python_3_15_host": "unit_test_interpreter_target",
        },
    )

    pypi.is_reproducible().equals(True)
    pypi.exposed_packages().contains_exactly({})
    pypi.hub_group_map().contains_exactly({})
    pypi.hub_whl_map().contains_exactly({"pypi": {}})
    pypi.whl_libraries().contains_exactly({})
    pypi.whl_mods().contains_exactly({})

_tests.append(_test_simple)

def extension_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
