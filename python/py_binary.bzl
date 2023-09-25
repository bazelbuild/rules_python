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

"""Public entry point for py_binary."""

load("@rules_python_internal//:rules_python_config.bzl", "config")
load("//python/private:util.bzl", "add_migration_tag")
load("//python/private/common:py_binary_macro_bazel.bzl", _starlark_py_binary = "py_binary")

# buildifier: disable=native-python
_py_binary_impl = _starlark_py_binary if config.enable_pystar else native.py_binary

def py_binary(**attrs):
    """See the Bazel core [py_binary](https://docs.bazel.build/versions/master/be/python.html#py_binary) documentation.

    Args:
      **attrs: Rule attributes
    """
    if attrs.get("python_version") == "PY2":
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")
    if attrs.get("srcs_version") in ("PY2", "PY2ONLY"):
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")

    _py_binary_impl(**add_migration_tag(attrs))
