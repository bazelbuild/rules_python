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

"""Macro to generate all of the targets present in a {obj}`whl_library`."""

load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load(
    ":labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
)

def whl_library_targets(
        name,
        *,
        filegroups = {
            DIST_INFO_LABEL: ["site-packages/*.dist-info/**"],
            DATA_LABEL: ["data/**"],
        },
        dependencies_by_platform = {},
        copy_files = {},
        copy_executables = {},
        native = native,
        copy_file_rule = copy_file):
    """Create all of the whl_library targets.

    Args:
        name: {type}`str` Currently unused.
        filegroups: {type}`dict[str, list[str]]` A dictionary of the target
            names and the glob matches.
        dependencies_by_platform: {type}`dict[str, list[str]]` A list of
            dependencies by platform key.
        copy_executables: {type}`dict[str, str]` The mapping between src and
            dest locations for the targets.
        copy_files: {type}`dict[str, str]` The mapping between src and
            dest locations for the targets.
        native: {type}`native` The native struct for overriding in tests.
        copy_file_rule: {type}`rule` The rule to declare copy targets.
    """
    _ = name  # buildifier: @unused
    for name, glob in filegroups.items():
        native.filegroup(
            name = name,
            srcs = native.glob(glob, allow_empty = True),
        )

    for src, dest in copy_files.items():
        _copy_file(src, dest, rule = copy_file_rule)
    for src, dest in copy_executables.items():
        _copy_file(src, dest, is_executable = True, rule = copy_file_rule)

    _config_settings(dependencies_by_platform.keys(), native = native)

def _config_settings(dependencies_by_platform, native = native):
    """Generate config settings for the targets.

    Args:
        dependencies_by_platform: {type}`list[str]` platform keys, can be
            one of the following formats:
            * `//conditions:default`
            * `@platforms//os:{value}`
            * `@platforms//cpu:{value}`
            * `@//python/config_settings:is_python_3.{minor_version}`
            * `{os}_{cpu}`
            * `cp3{minor_version}_{os}_{cpu}`
        native: {type}`native` The native struct for overriding in tests.
    """
    for p in dependencies_by_platform:
        if p.startswith("@") or p.endswith("default"):
            continue

        abi, _, tail = p.partition("_")
        if not abi.startswith("cp"):
            tail = p
            abi = ""

        os, _, arch = tail.partition("_")
        os = "" if os == "anyos" else os
        arch = "" if arch == "anyarch" else arch

        constraint_values = []
        if arch:
            constraint_values.append("@platforms//cpu:{}".format(arch))
        if os:
            constraint_values.append("@platforms//os:{}".format(os))

        if abi:
            flag_values = {
                "@rules_python//python/config_settings:python_version_major_minor": "3.{minor_version}".format(
                    minor_version = abi[len("cp3"):],
                ),
            }
        else:
            flag_values = None

        native.config_setting(
            name = "is_{name}".format(
                name = p.replace("cp3", "python_3."),
            ),
            flag_values = flag_values,
            constraint_values = constraint_values,
            visibility = ["//visibility:private"],
        )

def _copy_file(src, dest, *, is_executable = False, rule = copy_file):
    rule(
        name = dest + ".copy",
        src = src,
        out = dest,
        is_executable = is_executable,
    )
