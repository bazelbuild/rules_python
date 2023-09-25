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

"""Public entry point for py_library."""

load("@rules_python_internal//:rules_python_config.bzl", "config")
load("//python/private:util.bzl", "add_migration_tag")
load("//python/private/common:py_library_macro_bazel.bzl", _starlark_py_library = "py_library")

# buildifier: disable=native-python
_py_library_impl = _starlark_py_library if config.enable_pystar else native.py_library

def py_library(**attrs):
    """See the Bazel core [py_library](https://docs.bazel.build/versions/master/be/python.html#py_library) documentation.

    Args:
      **attrs: Rule attributes
    """
    if attrs.get("srcs_version") in ("PY2", "PY2ONLY"):
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")

    _py_library_impl(**add_migration_tag(attrs))
