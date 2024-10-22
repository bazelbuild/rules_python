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
load("@rules_testing//lib:truth.bzl", "subjects")
load("//python/private/pypi:extension.bzl", "parse_modules")  # buildifier: disable=bzl-visibility

_tests = []

def _mock_mctx(*modules, environ = {}, read = None):
    return struct(
        os = struct(
            environ = environ,
            name = "unittest",
            arch = "exotic",
        ),
        read = read or (lambda _: "simple==0.0.1 --hash=sha256:deadbeef"),
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
    return env.expect.that_struct(
        parse_modules(**kwargs),
        attrs = dict(
            is_reproducible = subjects.bool,
            exposed_packages = subjects.dict,
            hub_group_map = subjects.dict,
            hub_whl_map = subjects.dict,
            whl_libraries = subjects.dict,
            whl_mods = subjects.dict,
        ),
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
        isolated = True,
        netrc = None,
        pip_data_exclude = None,
        python_interpreter = None,
        python_interpreter_target = None,
        quiet = True,
        requirements_by_platform = {},
        requirements_darwin = None,
        requirements_linux = None,
        requirements_lock = None,
        requirements_windows = None,
        timeout = 600,
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
        # The following are covered by other unit tests
        experimental_extra_index_urls = [],
        parallel_download = False,
        experimental_index_url_overrides = {},
        **kwargs
    )

def _test_simple(env):
    pypi = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                name = "rules_python",
                parse = [
                    _parse(
                        hub_name = "pypi",
                        python_version = "3.15",
                        requirements_lock = "requirements.txt",
                    ),
                ],
            ),
        ),
        available_interpreters = {
            "python_3_15_host": "unit_test_interpreter_target",
        },
    )

    pypi.is_reproducible().equals(True)
    pypi.exposed_packages().contains_exactly({"pypi": ["simple"]})
    pypi.hub_group_map().contains_exactly({"pypi": {}})
    pypi.hub_whl_map().contains_exactly({"pypi": {
        "simple": [
            struct(
                config_setting = "//_config:is_python_3.15",
                filename = None,
                repo = "pypi_315_simple",
                target_platforms = None,
                version = "3.15",
            ),
        ],
    }})
    pypi.whl_libraries().contains_exactly({
        "pypi_315_simple": {
            "dep_template": "@pypi//{name}:{target}",
            "python_interpreter_target": "unit_test_interpreter_target",
            "repo": "pypi_315",
            "requirement": "simple==0.0.1 --hash=sha256:deadbeef",
        },
    })
    pypi.whl_mods().contains_exactly({})

_tests.append(_test_simple)

def _test_simple_multiple_requirements(env):
    pypi = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                name = "rules_python",
                parse = [
                    _parse(
                        hub_name = "pypi",
                        python_version = "3.15",
                        requirements_darwin = "darwin.txt",
                        requirements_windows = "win.txt",
                    ),
                ],
            ),
            read = lambda x: {
                "darwin.txt": "simple==0.0.2 --hash=sha256:deadb00f",
                "win.txt": "simple==0.0.1 --hash=sha256:deadbeef",
            }[x],
        ),
        available_interpreters = {
            "python_3_15_host": "unit_test_interpreter_target",
        },
    )

    pypi.is_reproducible().equals(True)
    pypi.exposed_packages().contains_exactly({"pypi": ["simple"]})
    pypi.hub_group_map().contains_exactly({"pypi": {}})
    pypi.hub_whl_map().contains_exactly({"pypi": {
        "simple": [
            struct(
                config_setting = "//_config:is_python_3.15",
                filename = None,
                repo = "pypi_315_simple__0",
                target_platforms = [
                    "cp315_windows_x86_64",
                ],
                version = "3.15",
            ),
            struct(
                config_setting = "//_config:is_python_3.15",
                filename = None,
                repo = "pypi_315_simple__1",
                target_platforms = [
                    "cp315_osx_aarch64",
                    "cp315_osx_x86_64",
                ],
                version = "3.15",
            ),
        ],
    }})
    pypi.whl_libraries().contains_exactly({
        "pypi_315_simple__0": {
            "dep_template": "@pypi//{name}:{target}",
            "python_interpreter_target": "unit_test_interpreter_target",
            "repo": "pypi_315",
            "requirement": "simple==0.0.1 --hash=sha256:deadbeef",
        },
        "pypi_315_simple__1": {
            "dep_template": "@pypi//{name}:{target}",
            "python_interpreter_target": "unit_test_interpreter_target",
            "repo": "pypi_315",
            "requirement": "simple==0.0.2 --hash=sha256:deadb00f",
        },
    })
    pypi.whl_mods().contains_exactly({})

_tests.append(_test_simple_multiple_requirements)

def _test_simple_get_index(env):
    got_simpleapi_download_args = []
    got_simpleapi_download_kwargs = {}

    def mocksimpleapi_download(*args, **kwargs):
        got_simpleapi_download_args.extend(args)
        got_simpleapi_download_kwargs.update(kwargs)
        return {
            "simple": struct(
                whls = {},
                sdists = {
                    "deadbeef": struct(
                        yanked = False,
                        filename = "simple-0.0.1.tar.gz",
                        sha256 = "deadbeef",
                        url = "example.org",
                    ),
                },
            ),
        }

    pypi = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                name = "rules_python",
                parse = [
                    _parse(
                        hub_name = "pypi",
                        python_version = "3.15",
                        requirements_lock = "requirements.txt",
                        experimental_index_url = "pypi.org",
                    ),
                ],
            ),
        ),
        available_interpreters = {
            "python_3_15_host": "unit_test_interpreter_target",
        },
        simpleapi_download = mocksimpleapi_download,
    )

    pypi.is_reproducible().equals(False)
    pypi.exposed_packages().contains_exactly({"pypi": ["simple"]})
    pypi.hub_group_map().contains_exactly({"pypi": {}})
    pypi.hub_whl_map().contains_exactly({"pypi": {
        "simple": [
            struct(
                config_setting = "//_config:is_python_3.15",
                filename = "simple-0.0.1.tar.gz",
                repo = "pypi_315_simple_sdist_deadbeef",
                target_platforms = None,
                version = "3.15",
            ),
        ],
    }})
    pypi.whl_libraries().contains_exactly({
        "pypi_315_simple_sdist_deadbeef": {
            "dep_template": "@pypi//{name}:{target}",
            "experimental_target_platforms": [
                "cp315_linux_aarch64",
                "cp315_linux_arm",
                "cp315_linux_ppc",
                "cp315_linux_s390x",
                "cp315_linux_x86_64",
                "cp315_osx_aarch64",
                "cp315_osx_x86_64",
                "cp315_windows_x86_64",
            ],
            "filename": "simple-0.0.1.tar.gz",
            "python_interpreter_target": "unit_test_interpreter_target",
            "repo": "pypi_315",
            "requirement": "simple==0.0.1",
            "sha256": "deadbeef",
            "urls": ["example.org"],
        },
    })
    pypi.whl_mods().contains_exactly({})

_tests.append(_test_simple_get_index)

def extension_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)