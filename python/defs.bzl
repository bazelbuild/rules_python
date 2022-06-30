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

"""
Core rules for building Python projects.
"""

load("@bazel_tools//tools/python:srcs_version.bzl", _find_requirements = "find_requirements")
load("@bazel_tools//tools/python:toolchain.bzl", _py_runtime_pair = "py_runtime_pair")
load(
    "//python/private:reexports.bzl",
    "internal_PyInfo",
    "internal_PyRuntimeInfo",
    _py_binary = "py_binary",
    _py_library = "py_library",
    _py_runtime = "py_runtime",
    _py_test = "py_test",
)

# Exports of native-defined providers.

PyInfo = internal_PyInfo

PyRuntimeInfo = internal_PyRuntimeInfo

def _current_py_toolchain_impl(ctx):
    toolchain = ctx.toolchains[ctx.attr._toolchain]

    direct = []
    transitive = []
    vars = {}

    if toolchain.py3_runtime and toolchain.py3_runtime.interpreter:
        direct.append(toolchain.py3_runtime.interpreter)
        transitive.append(toolchain.py3_runtime.files)
        vars["PYTHON3"] = toolchain.py3_runtime.interpreter.path

    if toolchain.py2_runtime and toolchain.py2_runtime.interpreter:
        direct.append(toolchain.py2_runtime.interpreter)
        transitive.append(toolchain.py2_runtime.files)
        vars["PYTHON2"] = toolchain.py2_runtime.interpreter.path

    files = depset(direct, transitive = transitive)
    return [
        toolchain,
        platform_common.TemplateVariableInfo(vars),
        DefaultInfo(
            runfiles = ctx.runfiles(transitive_files = files),
            files = files,
        ),
    ]

current_py_toolchain = rule(
    doc = """
    This rule exists so that the current python toolchain can be used in the `toolchains` attribute of
    other rules, such as genrule. It allows exposing a python toolchain after toolchain resolution has
    happened, to a rule which expects a concrete implementation of a toolchain, rather than a
    toolchain_type which could be resolved to that toolchain.
    """,
    implementation = _current_py_toolchain_impl,
    attrs = {
        "_toolchain": attr.string(default = str(Label("@bazel_tools//tools/python:toolchain_type"))),
    },
    toolchains = [
        str(Label("@bazel_tools//tools/python:toolchain_type")),
    ],
)

def _py_import_impl(ctx):
    # See https://github.com/bazelbuild/bazel/blob/0.24.0/src/main/java/com/google/devtools/build/lib/bazel/rules/python/BazelPythonSemantics.java#L104 .
    import_paths = [
        "/".join([ctx.workspace_name, x.short_path])
        for x in ctx.files.srcs
    ]

    return [
        DefaultInfo(
            default_runfiles = ctx.runfiles(ctx.files.srcs, collect_default = True),
        ),
        PyInfo(
            transitive_sources = depset(transitive = [
                dep[PyInfo].transitive_sources
                for dep in ctx.attr.deps
            ]),
            imports = depset(direct = import_paths, transitive = [
                dep[PyInfo].imports
                for dep in ctx.attr.deps
            ]),
        ),
    ]

py_import = rule(
    doc = """This rule allows the use of Python packages as dependencies.

    It imports the given `.egg` file(s), which might be checked in source files,
    fetched externally as with `http_file`, or produced as outputs of other rules.

    It may be used like a `py_library`, in the `deps` of other Python rules.

    This is similar to [java_import](https://docs.bazel.build/versions/master/be/java.html#java_import).
    """,
    implementation = _py_import_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "The list of other libraries to be linked in to the " +
                  "binary target.",
            providers = [PyInfo],
        ),
        "srcs": attr.label_list(
            doc = "The list of Python package files provided to Python targets " +
                  "that depend on this target. Note that currently only the .egg " +
                  "format is accepted. For .whl files, try the whl_library rule. " +
                  "We accept contributions to extend py_import to handle .whl.",
            allow_files = [".egg"],
        ),
    },
)

# Re-exports of Starlark-defined symbols in @bazel_tools//tools/python.

py_runtime_pair = _py_runtime_pair

find_requirements = _find_requirements

py_library = _py_library

py_binary = _py_binary

py_test = _py_test

py_runtime = _py_runtime
