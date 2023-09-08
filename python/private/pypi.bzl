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

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("//python/private:wheel_library.bzl", "pycross_wheel_library")
load("//python:defs.bzl", "py_library")
load(":pypi_util.bzl", "generate_repo_name_for_extracted_wheel")


_FORWARDED_ARGS = (
    ("patches", None),
    ("patch_args", None),
    ("patch_tool", None),
    ("patch_dir", None),
)

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

def _no_transform(value):
    return value

def _forward_arg(kwargs, intermediate, package, arg_name, default, transform):
    select_dict = {}

    for config, info in intermediate[package].items():
        select_dict[config] = transform(info.get(arg_name, default))

    kwargs[arg_name] = select(select_dict)


def _accumulate_transitive_deps_inner(intermediate, configs, package, already_accumulated):
    for config in configs:
        if config in intermediate[package]:
            deps = intermediate[package][config].get("deps", [])
        else:
            deps = intermediate["//conditions:default"][config].get("deps", [])

        new_deps = sets.difference(sets.make(deps), already_accumulated[config])
        already_accumulated[config] = sets.union(already_accumulated[config], new_deps)

        for dep in sets.to_list(new_deps):
            _accumulate_transitive_deps_inner(intermediate, configs, dep, already_accumulated)

def _accumulate_transitive_deps(intermediate, configs, package):
    already_accumulated = {config: sets.make([package]) for config in configs}
    _accumulate_transitive_deps_inner(intermediate, configs, package, already_accumulated)
    return select({config: sets.to_list(set) for config, set in already_accumulated})

def wrapped_py_wheel_library(name, alias_repo_name, wheel_repo_name, intermediate, configs, package):
    kwargs = {}
    for arg_name, default in _FORWARDED_ARGS:
        _forward_arg(kwargs, intermediate, package, arg_name, default, _no_transform)

    to_alias_refs = lambda deps: ["@{}//{}".format(alias_repo_name, dep) for dep in deps]

    _forward_arg(kwargs, intermediate, package, "deps", [], to_alias_refs)

    deps = _accumulate_transitive_deps(intermediate, configs, package)

    pycross_wheel_library(
        name = "underlying_library",
        wheel = "@{}//file".format(wheel_repo_name),
        enable_implicit_namespace_pkgs = True,
        # TODO(phil): Can we restrict visibility?
        visibility = ["//visibility:public"],
        deps = deps,
        **kwargs
    )

    py_library(
        name = name,
        deps = [
            ":underlying_library",
        ],
        visibility = ["//visibility:public"],
    )
