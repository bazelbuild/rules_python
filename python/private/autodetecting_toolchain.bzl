# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Definitions related to the Python toolchain."""

load("//python:py_runtime.bzl", "py_runtime")
load("//python:py_runtime_pair.bzl", "py_runtime_pair")

def define_autodetecting_toolchain(name):
    """Defines the autodetecting Python toolchain.

    Args:
        name: The name of the toolchain to introduce. Must have value
            "autodetecting_toolchain". This param is present only to make the
            BUILD file more readable.
    """
    if name != "autodetecting_toolchain":
        fail("Python autodetecting toolchain must be named " +
             "'autodetecting_toolchain'")

    # buildifier: disable=native-py
    py_runtime(
        name = "_autodetecting_py3_runtime",
        interpreter = ":py3wrapper.sh",
        python_version = "PY3",
        stub_shebang = "#!/usr/bin/env python3",
        visibility = ["//visibility:private"],
    )

    # This is a dummy runtime whose interpreter_path triggers the native rule
    # logic to use the legacy behavior on Windows.
    # TODO(#7844): Remove this target.
    # buildifier: disable=native-py
    py_runtime(
        name = "_magic_sentinel_runtime",
        interpreter_path = "/_magic_pyruntime_sentinel_do_not_use",
        python_version = "PY3",
        visibility = ["//visibility:private"],
    )

    py_runtime_pair(
        name = "_autodetecting_py_runtime_pair",
        py3_runtime = select({
            # If we're on windows, inject the sentinel to tell native rule logic
            # that we attempted to use the autodetecting toolchain and need to
            # switch back to legacy behavior.
            # TODO(#7844): Remove this hack.
            "@platforms//os:windows": ":_magic_sentinel_runtime",
            "//conditions:default": ":_autodetecting_py3_runtime",
        }),
        visibility = ["//visibility:public"],
    )

    native.toolchain(
        name = name,
        toolchain = ":_autodetecting_py_runtime_pair",
        toolchain_type = ":toolchain_type",
        visibility = ["//visibility:public"],
    )
