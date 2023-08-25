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
Creates an executable (a non-test binary) for console_script entry points.

Generate a `py_binary` target for a particular console_script `entry_point`
from a PyPI package, e.g. for creating an executable `pylint` target use:
```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "pylint",
    pkg = "@pip//pylint",
)
```

Or for more advanced setups you can also specify extra dependencies and the
exact script name you want to call. It is useful for tools like flake8, pylint,
pytest, which have plugin discovery methods and discover dependencies from the
PyPI packages available in the PYTHONPATH.
```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "pylint_with_deps",
    pkg = "@pip//pylint",
    # Because `pylint` has multiple console_scripts available, we have to
    # specify which we want if the name of the target name 'pylint_with_deps'
    # cannot be used to guess the entry_point script.
    script = "pylint",
    deps = [
        # One can add extra dependencies to the entry point.
        # This specifically allows us to add plugins to pylint.
        "@pip//pylint_print",
    ],
)
```

A specific Python version can be forced by using the generated version-aware
wrappers, e.g. to force Python 3.9:
```starlark
load("@python_versions//3.9:defs.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "yamllint",
    pkg = "@pip//yamllint",
)
```

Alternatively, the the `py_console_script_binary.binary_rule` arg can be passed
the version-bound `py_binary` symbol, or any other `py_binary`-compatible rule
of your choosing:
```starlark
load("@python_versions//3.9:defs.bzl", "py_binary")
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "yamllint",
    pkg = "@pip//yamllint:pkg",
    binary_rule = py_binary,
)
```
"""

load("//python/private:py_console_script_binary.bzl", _py_console_script_binary = "py_console_script_binary")

py_console_script_binary = _py_console_script_binary
