# Copyright 2023 The Bazel Authors. All rights reserved.
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

load("//python/private:wheel_library.bzl", "pycross_wheel_library")
load(":pypi_util.bzl", "generate_repo_name_for_extracted_wheel")


def generate_package_alias(intermediate):
    package = native.package_name()
    if package not in intermediate:
        fail("Failed to find {} in the intermediate file. Something went wrong internally.")

    info_per_config = intermediate[package]
    actual_select = {}
    target_compatible_with_select = {
        "//conditions:default": ["@platforms//:incompatible"],
    }
    for config, info in info_per_config.items():
        repo_name = generate_repo_name_for_extracted_wheel(package, info)
        actual_select[config] = "@{}//:library".format(repo_name)
        target_compatible_with_select[config] = []

    native.alias(
        name = package,
        actual = select(actual_select),
        target_compatible_with = select(target_compatible_with_select),
        visibility = ["//visibility:public"],
    )


def wrapped_py_wheel_library(name, alias_repo_name, wheel_repo_name, info):
    kwargs = {arg: info.get(arg) for arg in (
        "patches",
        "patch_args",
        "patch_tool",
        "patch_dir",
    )}
    deps = ["@{}//{}".format(alias_repo_name, dep) for dep in info.get("deps", [])]
    pycross_wheel_library(
        name = "library",
        wheel = "@{}//file".format(wheel_repo_name),
        enable_implicit_namespace_pkgs = True,
        visibility = ["//visibility:public"],
        deps = deps,
        **kwargs
    )
