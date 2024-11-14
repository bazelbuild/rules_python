# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Create toolchain alias targets."""

load("@rules_python//python:versions.bzl", "PLATFORMS")

def toolchain_aliases(*, name, platforms, native = native):
    """Cretae toolchain aliases for the python toolchains.

    Args:
        name: {type}`str` The name of the current repository.
        platforms: {type}`platforms` The list of platforms that are supported
            for the current toolchain repository.
        native: The native struct used in the macro, useful for testing.
    """
    for platform in PLATFORMS.keys():
        if platform not in platforms:
            continue

        native.config_setting(
            name = platform,
            flag_values = PLATFORMS[platform].flag_values,
            constraint_values = PLATFORMS[platform].compatible_with,
            visibility = ["//visibility:private"],
        )

    native.alias(name = "files", actual = select({{":" + item: "@" + name + "_" + item + "//:files" for item in platforms}}))
    native.alias(name = "includes", actual = select({{":" + item: "@" + name + "_" + item + "//:includes" for item in platforms}}))
    native.alias(name = "libpython", actual = select({{":" + item: "@" + name + "_" + item + "//:libpython" for item in platforms}}))
    native.alias(name = "py3_runtime", actual = select({{":" + item: "@" + name + "_" + item + "//:py3_runtime" for item in platforms}}))
    native.alias(name = "python_headers", actual = select({{":" + item: "@" + name + "_" + item + "//:python_headers" for item in platforms}}))
    native.alias(name = "python_runtimes", actual = select({{":" + item: "@" + name + "_" + item + "//:python_runtimes" for item in platforms}}))
    native.alias(name = "python3", actual = select({{":" + item: "@" + name + "_" + item + "//:" + ("python.exe" if "windows" in item else "bin/python3") for item in platforms}}))
