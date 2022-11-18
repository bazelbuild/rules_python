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

"""Internal re-exports of built-in symbols.

Currently the definitions here are re-exports of the native rules, "blessed" to
work under `--incompatible_load_python_rules_from_bzl`. As the native rules get
migrated to Starlark, their implementations will be removed from here.

We want to re-export a built-in symbol as if it were defined in a Starlark
file, so that users can for instance do:

```
load("@rules_python//python:defs.bzl", "PyInfo")
```

Unfortunately, we can't just write in defs.bzl

```
PyInfo = PyInfo
```

because the declaration of module-level symbol `PyInfo` makes the builtin
inaccessible. So instead we access the builtin here and export it under a
different name. Then we can load it from defs.bzl and export it there under
the original name.
"""

load("@bazel_tools//tools/python:toolchain.bzl", _py_runtime_pair = "py_runtime_pair")

# The implementation of the macros and tagging mechanism follows the example
# set by rules_cc and rules_java.

_MIGRATION_TAG = "__PYTHON_RULES_MIGRATION_DO_NOT_USE_WILL_BREAK__"

def _add_tags(attrs):
    if "tags" in attrs and attrs["tags"] != None:
        attrs["tags"] = attrs["tags"] + [_MIGRATION_TAG]
    else:
        attrs["tags"] = [_MIGRATION_TAG]
    return attrs

# Don't use underscore prefix, since that would make the symbol local to this
# file only. Use a non-conventional name to emphasize that this is not a public
# symbol.
# buildifier: disable=name-conventions
internal_PyInfo = PyInfo

# buildifier: disable=name-conventions
internal_PyRuntimeInfo = PyRuntimeInfo

def py_library(**attrs):
    """See the Bazel core [py_library](https://docs.bazel.build/versions/master/be/python.html#py_library) documentation.

    Args:
      **attrs: Rule attributes
    """
    if attrs.get("srcs_version") in ("PY2", "PY2ONLY"):
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")

    # buildifier: disable=native-python
    native.py_library(**_add_tags(attrs))

def py_binary(**attrs):
    """See the Bazel core [py_binary](https://docs.bazel.build/versions/master/be/python.html#py_binary) documentation.

    Args:
      **attrs: Rule attributes
    """
    if attrs.get("python_version") == "PY2":
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")
    if attrs.get("srcs_version") in ("PY2", "PY2ONLY"):
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")

    # buildifier: disable=native-python
    native.py_binary(**_add_tags(attrs))

def py_test(**attrs):
    """See the Bazel core [py_test](https://docs.bazel.build/versions/master/be/python.html#py_test) documentation.

    Args:
      **attrs: Rule attributes
    """
    if attrs.get("python_version") == "PY2":
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")
    if attrs.get("srcs_version") in ("PY2", "PY2ONLY"):
        fail("Python 2 is no longer supported: https://github.com/bazelbuild/rules_python/issues/886")

    # buildifier: disable=native-python
    native.py_test(**_add_tags(attrs))

def py_runtime(**attrs):
    """See the Bazel core [py_runtime](https://docs.bazel.build/versions/master/be/python.html#py_runtime) documentation.

    Args:
      **attrs: Rule attributes
    """
    if attrs.get("python_version") == "PY2":
        fail("Python 2 is no longer supported: see https://github.com/bazelbuild/rules_python/issues/886")

    # buildifier: disable=native-python
    native.py_runtime(**_add_tags(attrs))

# NOTE: This doc is copy/pasted from the builtin py_runtime_pair rule so our
# doc generator gives useful API docs.
def py_runtime_pair(name, py2_runtime = None, py3_runtime = None, **attrs):
    """A toolchain rule for Python.

    This used to wrap up to two Python runtimes, one for Python 2 and one for Python 3.
    However, Python 2 is no longer supported, so it now only wraps a single Python 3
    runtime.

    Usually the wrapped runtimes are declared using the `py_runtime` rule, but any
    rule returning a `PyRuntimeInfo` provider may be used.

    This rule returns a `platform_common.ToolchainInfo` provider with the following
    schema:

    ```python
    platform_common.ToolchainInfo(
        py2_runtime = None,
        py3_runtime = <PyRuntimeInfo or None>,
    )
    ```

    Example usage:

    ```python
    # In your BUILD file...

    load("@rules_python//python:defs.bzl", "py_runtime_pair")

    py_runtime(
        name = "my_py3_runtime",
        interpreter_path = "/system/python3",
        python_version = "PY3",
    )

    py_runtime_pair(
        name = "my_py_runtime_pair",
        py3_runtime = ":my_py3_runtime",
    )

    toolchain(
        name = "my_toolchain",
        target_compatible_with = <...>,
        toolchain = ":my_py_runtime_pair",
        toolchain_type = "@rules_python//python:toolchain_type",
    )
    ```

    ```python
    # In your WORKSPACE...

    register_toolchains("//my_pkg:my_toolchain")
    ```

    Args:
        name: str, the name of the target
        py2_runtime: optional Label; must be unset or None; an error is raised
            otherwise.
        py3_runtime: Label; a target with `PyRuntimeInfo` for Python 3.
        **attrs: Extra attrs passed onto the native rule
    """
    if attrs.get("py2_runtime"):
        fail("PYthon 2 is no longer supported: see https://github.com/bazelbuild/rules_python/issues/886")
    _py_runtime_pair(
        name = name,
        py2_runtime = py2_runtime,
        py3_runtime = py3_runtime,
        **attrs
    )
