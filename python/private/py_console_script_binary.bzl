# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""
Implementation for the macro to generate a console_script py_binary from an 'entry_points.txt' config.
"""

load("//python:py_binary.bzl", "py_binary")
load(":py_console_script_gen.bzl", "py_console_script_gen")

def _dist_info(pkg):
    """Return the first candidate for the dist_info target label.

    We cannot do `Label(pkg)` here because the string will be evaluated within
    the context of the rules_python repo_mapping and it will fail because
    rules_python does not know anything about the hub repos that the user has
    available.

    NOTE: Works with `incompatible_generate_aliases` and without by assuming the
    following formats:
        * @pypi_pylint//:pkg
        * @pypi//pylint
        * @pypi//pylint:pkg
        * Label("@pypi//pylint:pkg")
    """

    # str() is called to convert Label objects
    return str(pkg).replace(":pkg", "") + ":dist_info"

def py_console_script_binary(
        *,
        name,
        pkg,
        entry_points_txt = None,
        script = None,
        binary_rule = py_binary,
        **kwargs):
    """Generate a py_binary for a console_script entry_point.

    Args:
        name: str, The name of the resulting target.
        pkg: target, the package for which to generate the script.
        entry_points_txt: optional target, the entry_points.txt file to parse
            for available console_script values. It may be a single file, or a
            group of files, but must contain a file named `entry_points.txt`.
            If not specified, defaults to the `dist_info` target in the same
            package as the `pkg` Label.
        script: str, The console script name that the py_binary is going to be
            generated for. Defaults to the normalized name attribute.
        binary_rule: callable, The rule/macro to use to instantiate
            the target. It's expected to behave like `py_binary`.
            Defaults to @rules_python//python:py_binary.bzl#py_binary.
        **kwargs: Extra parameters forwarded to binary_rule.
    """
    main = "rules_python_entry_point_{}.py".format(name)

    if kwargs.pop("srcs", None):
        fail("passing 'srcs' attribute to py_console_script_binary is unsupported")

    py_console_script_gen(
        name = "_{}_gen".format(name),
        # NOTE @aignas 2023-08-05: Works with `incompatible_generate_aliases` and without.
        entry_points_txt = entry_points_txt or _dist_info(pkg),
        out = main,
        console_script = script,
        console_script_guess = name,
        visibility = ["//visibility:private"],
    )

    binary_rule(
        name = name,
        srcs = [main],
        main = main,
        deps = [pkg] + kwargs.pop("deps", []),
        **kwargs
    )
