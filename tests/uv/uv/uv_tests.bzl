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
load("//python/uv/private:uv.bzl", "parse_modules")  # buildifier: disable=bzl-visibility

_tests = []

def _mock_mctx(*modules, download = None, read = None):
    fake_fs = {
        "linux.sha256": "deadbeef linux",
        "manifest.json": json.encode({
            "artifacts": {
                x: {
                    "checksum": x + ".sha256",
                    "kind": "executable-zip",
                }
                for x in ["linux", "os", "osx"]
            } | {
                x + ".sha256": {
                    "name": x + ".sha256",
                    "target_triples": [x],
                }
                for x in ["linux", "os", "osx"]
            },
        }),
        "os.sha256": "deadbeef os",
        "osx.sha256": "deadb00f osx",
    }

    return struct(
        path = str,
        download = download or (lambda *_, **__: struct(
            success = True,
            wait = lambda: struct(
                success = True,
            ),
        )),
        read = read or (lambda x: fake_fs[x]),
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

def _mod(*, name = None, default = [], configure = [], is_root = True):
    return struct(
        name = name,  # module_name
        tags = struct(
            default = default,
            configure = configure,
        ),
        is_root = is_root,
    )

def _parse_modules(env, **kwargs):
    return env.expect.that_struct(
        parse_modules(**kwargs),
        attrs = dict(
            names = subjects.collection,
            labels = subjects.dict,
            compatible_with = subjects.dict,
            target_settings = subjects.dict,
        ),
    )

def _default(
        base_url = None,
        compatible_with = None,
        manifest_filename = None,
        platform = None,
        target_settings = None,
        version = None,
        **kwargs):
    return struct(
        base_url = base_url,
        compatible_with = [] + (compatible_with or []),  # ensure that the type is correct
        manifest_filename = manifest_filename,
        platform = platform,
        target_settings = [] + (target_settings or []),  # ensure that the type is correct
        version = version,
        **kwargs
    )

def _configure(**kwargs):
    # We have the same attributes
    return _default(**kwargs)

def _test_only_defaults(env):
    uv = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                default = [
                    _default(
                        base_url = "https://example.org",
                        manifest_filename = "manifest.json",
                        version = "1.0.0",
                    ),
                ],
            ),
        ),
    )

    # No defined platform means nothing gets registered
    uv.names().contains_exactly([
        "none",
    ])
    uv.labels().contains_exactly({
        "none": "@@//python:none",
    })
    uv.compatible_with().contains_exactly({
        "none": ["@platforms//:incompatible"],
    })
    uv.target_settings().contains_exactly({})

_tests.append(_test_only_defaults)

def _test_defaults(env):
    calls = []
    uv = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                default = [
                    _default(
                        base_url = "https://example.org",
                        manifest_filename = "manifest.json",
                        version = "1.0.0",
                        platform = "linux",
                        compatible_with = ["@platforms//os:linux"],
                        target_settings = ["//:my_flag"],
                    ),
                ],
                configure = [
                    _configure(),  # use defaults
                ],
            ),
        ),
        uv_repository = lambda **kwargs: calls.append(kwargs),
    )

    uv.names().contains_exactly([
        "uv_1_0_0_linux_toolchain",
    ])
    uv.labels().contains_exactly({
        "uv_1_0_0_linux_toolchain": "@uv_1_0_0_linux//:uv_toolchain",
    })
    uv.compatible_with().contains_exactly({
        "uv_1_0_0_linux_toolchain": ["@platforms//os:linux"],
    })
    uv.target_settings().contains_exactly({
        "uv_1_0_0_linux_toolchain": ["//:my_flag"],
    })
    env.expect.that_collection(calls).contains_exactly([
        {
            "name": "uv_1_0_0_linux",
            "platform": "linux",
            "sha256": "deadbeef",
            "urls": ["https://example.org/1.0.0/linux"],
            "version": "1.0.0",
        },
    ])

_tests.append(_test_defaults)

def _test_default_building(env):
    calls = []
    uv = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                default = [
                    _default(
                        base_url = "https://example.org",
                        manifest_filename = "manifest.json",
                        version = "1.0.0",
                    ),
                    _default(
                        platform = "linux",
                        compatible_with = ["@platforms//os:linux"],
                        target_settings = ["//:my_flag"],
                    ),
                    _default(
                        platform = "osx",
                        compatible_with = ["@platforms//os:osx"],
                    ),
                ],
                configure = [
                    _configure(),  # use defaults
                ],
            ),
        ),
        uv_repository = lambda **kwargs: calls.append(kwargs),
    )

    uv.names().contains_exactly([
        "uv_1_0_0_linux_toolchain",
        "uv_1_0_0_osx_toolchain",
    ])
    uv.labels().contains_exactly({
        "uv_1_0_0_linux_toolchain": "@uv_1_0_0_linux//:uv_toolchain",
        "uv_1_0_0_osx_toolchain": "@uv_1_0_0_osx//:uv_toolchain",
    })
    uv.compatible_with().contains_exactly({
        "uv_1_0_0_linux_toolchain": ["@platforms//os:linux"],
        "uv_1_0_0_osx_toolchain": ["@platforms//os:osx"],
    })
    uv.target_settings().contains_exactly({
        "uv_1_0_0_linux_toolchain": ["//:my_flag"],
        "uv_1_0_0_osx_toolchain": [],
    })
    env.expect.that_collection(calls).contains_exactly([
        {
            "name": "uv_1_0_0_linux",
            "platform": "linux",
            "sha256": "deadbeef",
            "urls": ["https://example.org/1.0.0/linux"],
            "version": "1.0.0",
        },
        {
            "name": "uv_1_0_0_osx",
            "platform": "osx",
            "sha256": "deadb00f",
            "urls": ["https://example.org/1.0.0/osx"],
            "version": "1.0.0",
        },
    ])

_tests.append(_test_default_building)

def _test_complex_configuring(env):
    calls = []
    uv = _parse_modules(
        env,
        module_ctx = _mock_mctx(
            _mod(
                default = [
                    _default(
                        base_url = "https://example.org",
                        manifest_filename = "manifest.json",
                        version = "1.0.0",
                        platform = "os",
                        compatible_with = ["@platforms//os:os"],
                    ),
                ],
                configure = [
                    _configure(),  # use defaults
                    _configure(
                        version = "1.0.1",
                    ),  # use defaults
                    _configure(
                        version = "1.0.2",
                        base_url = "something_different",
                        manifest_filename = "different.json",
                    ),  # use defaults
                    _configure(
                        platform = "os",
                        compatible_with = ["@platforms//os:different"],
                    ),
                    _configure(
                        version = "1.0.3",
                    ),
                    _configure(platform = "os"),  # remove the default
                    _configure(
                        platform = "linux",
                        compatible_with = ["@platforms//os:linux"],
                    ),
                ],
            ),
        ),
        uv_repository = lambda **kwargs: calls.append(kwargs),
    )

    uv.names().contains_exactly([])
    uv.labels().contains_exactly({})
    uv.compatible_with().contains_exactly({})
    uv.target_settings().contains_exactly({})
    env.expect.that_collection(calls).contains_exactly([
    ])

_tests.append(_test_complex_configuring)

def uv_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
