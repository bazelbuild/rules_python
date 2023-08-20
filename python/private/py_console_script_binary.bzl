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
Implementation for the macro to generate an console_script py_binary from reading the 'entry_points.txt'.
"""

load("//python:py_binary.bzl", "py_binary")
load(":py_console_script_gen.bzl", "py_console_script_gen")

def py_console_script_binary(*, name, pkg, script = None, binary_rule = py_binary, **kwargs):
    """Generate a py_binary for a console_script entry_point.

    Args:
        name: The name of the resultant binary_rule target.
        pkg: The package for which to generate the script.
        script: The console script name that the py_binary is going to be
            generated for. Mandatory only if there is more than 1
            console_script in the package.
        binary_rule: The binary rule to call to create the py_binary.
            Defaults to @rules_python//python:py_binary.bzl#py_binary.
        **kwargs: Extra parameters forwarded to binary_rule.
    """
    main = "rules_python_entry_point_{}.py".format(name)

    if kwargs.pop("srcs", None):
        fail("passing 'srcs' attribute to py_console_script_binary is unsupported")

    py_console_script_gen(
        name = "_{}_gen".format(name),
        # NOTE @aignas 2023-08-05: Works with `incompatible_generate_aliases` and without.
        dist_info = pkg.replace(":pkg", "") + ":dist_info",
        out = main,
        console_script = script,
        visibility = ["//visibility:private"],
    )

    binary_rule(
        name = name,
        srcs = [main],
        main = main,
        deps = [pkg] + kwargs.pop("deps", []),
        **kwargs
    )
