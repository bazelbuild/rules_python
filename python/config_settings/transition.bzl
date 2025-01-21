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

"""The transition module contains the rule definitions to wrap py_binary and py_test and transition
them to the desired target platform.

:::{versionchanged} 1.1.0
The `py_binary` and `py_test` symbols are aliases to the regular rules. Usages
of them should be changed to load the regular rules directly.
:::
"""

load("//python:py_binary.bzl", _py_binary = "py_binary")
load("//python:py_test.bzl", _py_test = "py_test")

_DEPRECATION_MESSAGE = """
The '{name}' symbol in @{deprecated}
is deprecated. It is an alias to the regular rule; use it directly instead:

load("@rules_python//python{load_name}.bzl", "{name}")

{name}(
    # ...
    python_version = "{python_version}",
    # ...
)
"""

def with_deprecation(kwargs, *, symbol_name, python_version, load_name = None, deprecated = "rules_python//python/config_settings:transition.bzl"):
    """An internal function to propagate the deprecation warning.

    This is not an API that should be used outside `rules_python`.

    Args:
        kwargs: Arguments to modify.
        symbol_name: {type}`str` the symbol name that is deprecated.
        python_version: {type}`str` the python version to be used.
        load_name: {type}`str` the load location under `//python`. Should start
            either with `/` or `:`. Defaults to `:<symbol_name>`.
        deprecated: {type}`str` the symbol import location that we are deprecating.

    Returns:
        The kwargs to be used in the macro creation.
    """

    # TODO @aignas 2025-01-21: should we add a flag that silences this?
    load_name = load_name or (":" + symbol_name)

    deprecation = _DEPRECATION_MESSAGE.format(
        name = symbol_name,
        load_name = load_name,
        python_version = python_version,
        deprecated = deprecated,
    )
    if kwargs.get("deprecation"):
        deprecation = kwargs.get("deprecation") + "\n\n" + deprecation
    kwargs["deprecation"] = deprecation
    kwargs["python_version"] = python_version
    return kwargs

def py_binary(**kwargs):
    """[DEPRECATED] Deprecated alias for py_binary.

    Args:
        **kwargs: keyword args forwarded onto {obj}`py_binary`.
    """

    _py_binary(**with_deprecation(kwargs, name = "py_binary", python_version = kwargs.get("python_version")))

def py_test(**kwargs):
    """[DEPRECATED] Deprecated alias for py_test.

    Args:
        **kwargs: keyword args forwarded onto {obj}`py_binary`.
    """
    _py_test(**with_deprecation(kwargs, name = "py_test", python_version = kwargs.get("python_version")))
