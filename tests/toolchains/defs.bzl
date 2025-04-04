# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

""

load("@pythons_hub//:versions.bzl", "DEFAULT_PYTHON_VERSION", "MINOR_MAPPING")
load("//python:versions.bzl", "PLATFORMS", "TOOL_VERSIONS")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility
load("//python/private:full_version.bzl", "full_version")  # buildifier: disable=bzl-visibility
load("//tests/support:sh_py_run_test.bzl", "py_reconfig_test")

def define_toolchain_tests(name):
    """Define the toolchain tests.

    Args:
        name: Only present to satisfy tooling.
    """
    for platform_key, platform_info in PLATFORMS.items():
        native.config_setting(
            name = "_is_{}".format(platform_key),
            flag_values = platform_info.flag_values,
            constraint_values = platform_info.compatible_with,
        )

    # First we expect the transitions with a specific version to always
    # give us that specific version
    exact_version_tests = {
        (v, v): "python_{}_test".format(v)
        for v in TOOL_VERSIONS
    }
    native.test_suite(
        name = "exact_version_tests",
        tests = exact_version_tests.values(),
    )

    # Then we expect to get the version in the MINOR_MAPPING if we provide
    # the version from the MINOR_MAPPING
    minor_mapping_tests = {
        (minor, full): "python_{}_test".format(minor)
        for minor, full in MINOR_MAPPING.items()
    }
    native.test_suite(
        name = "minor_mapping_tests",
        tests = minor_mapping_tests.values(),
    )

    # Lastly, if we don't provide any version to the transition, we should
    # get the default version
    default_version = full_version(
        # note, this hard codes the version that is in //:WORKSPACE
        version = DEFAULT_PYTHON_VERSION if BZLMOD_ENABLED else "3.11",
        minor_mapping = MINOR_MAPPING,
    )
    default_version_tests = {
        (None, default_version): "default_version_test",
    }
    tests = exact_version_tests | minor_mapping_tests | default_version_tests

    for (input_python_version, expect_python_version), test_name in tests.items():
        meta = TOOL_VERSIONS[expect_python_version]
        target_compatible_with = {
            "//conditions:default": ["@platforms//:incompatible"],
        }
        for platform_key in meta["sha256"].keys():
            is_platform = "_is_{}".format(platform_key)
            target_compatible_with[is_platform] = []

        py_reconfig_test(
            name = test_name,
            srcs = ["python_toolchain_test.py"],
            main = "python_toolchain_test.py",
            python_version = input_python_version,
            env = {
                "EXPECT_PYTHON_VERSION": expect_python_version,
            },
            deps = ["//python/runfiles"],
            data = ["//tests/support:current_build_settings"],
            target_compatible_with = select(target_compatible_with),
        )
