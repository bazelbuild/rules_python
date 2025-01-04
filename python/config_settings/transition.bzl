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

:::{versionchanged} VERSION_NEXT_PATCH
The `py_binary` and `py_test` symbols are aliases to the regular rules. Usages
of them should be changed to load the regular rules directly.
:::
"""

load("//python:py_binary.bzl", _py_binary = "py_binary")
load("//python:py_test.bzl", _py_test = "py_test")

_DEPRECATION_MESSAGE = """
The {name} symbol in @rules_python//python/config_settings:transition.bzl
is deprecated. It is an alias to the regular rule; use it directly instead:
    load("@rules_python//python:{name}.bzl", "{name}")
"""

def py_binary(**kwargs):
    """[DEPRECATED] Deprecated alias for py_binary.

    Args:
        **kwargs: keyword args forwarded onto {obj}`py_binary`.
    """

    deprecation = _DEPRECATION_MESSAGE.format(name = "py_binary")
    if kwargs.get("deprecation"):
        deprecation = kwargs.get("deprecation") + "\n\n" + deprecation
    kwargs["deprecation"] = deprecation
    _py_binary(**kwargs)

def py_test(**kwargs):
    """[DEPRECATED] Deprecated alias for py_test.

    Args:
        **kwargs: keyword args forwarded onto {obj}`py_binary`.
    """
    deprecation = _DEPRECATION_MESSAGE.format(name = "py_test")
    if kwargs.get("deprecation"):
        deprecation = kwargs.get("deprecation") + "\n\n" + deprecation
    kwargs["deprecation"] = deprecation
    _py_test(**kwargs)
