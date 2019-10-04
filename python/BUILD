# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""This package contains two sets of rules:

    1) the "core" Python rules, which were historically bundled with Bazel and
       are now either re-exported or copied into this repository; and

    2) the packaging rules, which were historically simply known as
       rules_python.

In an ideal renaming, we'd move the packaging rules to a different package so
that @rules_python//python is only concerned with the core rules.
"""

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "distribution",
    srcs = glob(["**"]) + [
        "//python/constraints:distribution",
        "//python/runfiles:distribution",
    ],
    visibility = ["//:__pkg__"],
)

# ========= Core rules =========

exports_files([
    "defs.bzl",
    "python.bzl",  # Deprecated, please use defs.bzl
])

# Needed to define bzl_library targets for docgen. (We don't define the
# bzl_library target here because it'd give our users a transitive dependency
# on Skylib.)
exports_files(["private/reexports.bzl"], visibility = ["//docs:__pkg__"])

# This target can be used to inspect the current Python major version. To use,
# put it in the `flag_values` attribute of a `config_setting` and test it
# against the values "PY2" or "PY3". It will always match one or the other.
#
# If you do not need to test any other flags in combination with the Python
# version, then as a convenience you may use the predefined `config_setting`s
# `@rules_python//python:PY2` and `@rules_python//python:PY3`.
#
# Example usage:
#
#     config_setting(
#         name = "py3_on_arm",
#         values = {"cpu": "arm"},
#         flag_values = {"@rules_python//python:python_version": "PY3"},
#     )
#
#     my_target(
#         ...
#         some_attr = select({
#             ":py3_on_arm": ...,
#             ...
#         }),
#         ...
#     )
#
# Caution: Do not `select()` on the built-in command-line flags `--force_python`
# or `--python_version`, as they do not always reflect the true Python version
# of the current target. `select()`-ing on them can lead to action conflicts and
# will be disallowed.
alias(
    name = "python_version",
    actual = "@bazel_tools//tools/python:python_version",
)

alias(
    name = "PY2",
    actual = "@bazel_tools//tools/python:PY2",
)

alias(
    name = "PY3",
    actual = "@bazel_tools//tools/python:PY3",
)

# The toolchain type for Python rules. Provides a Python 2 and/or Python 3
# runtime.
alias(
    name = "toolchain_type",
    actual = "@bazel_tools//tools/python:toolchain_type",
)

# Definitions for a Python toolchain that, at execution time, attempts to detect
# a platform runtime having the appropriate major Python version. Consider this
# a toolchain of last resort.
#
# The non-strict version allows using a Python 2 interpreter for PY3 targets,
# and vice versa. The only reason to use this is if you're working around
# spurious failures due to PY2 vs PY3 validation. Even then, using this is only
# safe if you know for a fact that your build is completely compatible with the
# version of the `python` command installed on the target platform.

alias(
    name = "autodetecting_toolchain",
    actual = "@bazel_tools//tools/python:autodetecting_toolchain",
)

alias(
    name = "autodetecting_toolchain_nonstrict",
    actual = "@bazel_tools//tools/python:autodetecting_toolchain_nonstrict",
)

# ========= Packaging rules =========

exports_files([
    "pip.bzl",
    "whl.bzl",
])
