# Copyright 2022 The Bazel Authors. All rights reserved.
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
"""Providers for Python rules."""

load("@rules_python_internal//:rules_python_config.bzl", "config")
load(":semantics.bzl", "TOOLS_REPO")

# TODO: load CcInfo from rules_cc
_CcInfo = CcInfo

DEFAULT_STUB_SHEBANG = "#!/usr/bin/env python3"

DEFAULT_BOOTSTRAP_TEMPLATE = "@" + TOOLS_REPO + "//tools/python:python_bootstrap_template.txt"
_PYTHON_VERSION_VALUES = ["PY2", "PY3"]

# Helper to make the provider definitions not crash under Bazel 5.4:
# Bazel 5.4 doesn't support the `init` arg of `provider()`, so we have to
# not pass that when using Bazel 5.4. But, not passing the `init` arg
# changes the return value from a two-tuple to a single value, which then
# breaks Bazel 6+ code.
# This isn't actually used under Bazel 5.4, so just stub out the values
# to get past the loading phase.
def _define_provider(doc, fields, **kwargs):
    if not config.enable_pystar:
        return provider("Stub, not used", fields = []), None
    return provider(doc = doc, fields = fields, **kwargs)

def _PyRuntimeInfo_init(
        *,
        interpreter_path = None,
        interpreter = None,
        files = None,
        coverage_tool = None,
        coverage_files = None,
        python_version,
        stub_shebang = None,
        bootstrap_template = None):
    if (interpreter_path and interpreter) or (not interpreter_path and not interpreter):
        fail("exactly one of interpreter or interpreter_path must be specified")

    if interpreter_path and files != None:
        fail("cannot specify 'files' if 'interpreter_path' is given")

    if (coverage_tool and not coverage_files) or (not coverage_tool and coverage_files):
        fail(
            "coverage_tool and coverage_files must both be set or neither must be set, " +
            "got coverage_tool={}, coverage_files={}".format(
                coverage_tool,
                coverage_files,
            ),
        )

    if python_version not in _PYTHON_VERSION_VALUES:
        fail("invalid python_version: '{}'; must be one of {}".format(
            python_version,
            _PYTHON_VERSION_VALUES,
        ))

    if files != None and type(files) != type(depset()):
        fail("invalid files: got value of type {}, want depset".format(type(files)))

    if interpreter:
        if files == None:
            files = depset()
    else:
        files = None

    if coverage_files == None:
        coverage_files = depset()

    if not stub_shebang:
        stub_shebang = DEFAULT_STUB_SHEBANG

    return {
        "bootstrap_template": bootstrap_template,
        "coverage_files": coverage_files,
        "coverage_tool": coverage_tool,
        "files": files,
        "interpreter": interpreter,
        "interpreter_path": interpreter_path,
        "python_version": python_version,
        "stub_shebang": stub_shebang,
    }

# TODO(#15897): Rename this to PyRuntimeInfo when we're ready to replace the Java
# implemented provider with the Starlark one.
PyRuntimeInfo, _unused_raw_py_runtime_info_ctor = _define_provider(
    doc = """Contains information about a Python runtime, as returned by the `py_runtime`
rule.

A Python runtime describes either a *platform runtime* or an *in-build runtime*.
A platform runtime accesses a system-installed interpreter at a known path,
whereas an in-build runtime points to a `File` that acts as the interpreter. In
both cases, an "interpreter" is really any executable binary or wrapper script
that is capable of running a Python script passed on the command line, following
the same conventions as the standard CPython interpreter.
""",
    init = _PyRuntimeInfo_init,
    fields = {
        "bootstrap_template": (
            "See py_runtime_rule.bzl%py_runtime.bootstrap_template for docs."
        ),
        "coverage_files": (
            "The files required at runtime for using `coverage_tool`. " +
            "Will be `None` if no `coverage_tool` was provided."
        ),
        "coverage_tool": (
            "If set, this field is a `File` representing tool used for collecting code coverage information from python tests. Otherwise, this is `None`."
        ),
        "files": (
            "If this is an in-build runtime, this field is a `depset` of `File`s" +
            "that need to be added to the runfiles of an executable target that " +
            "uses this runtime (in particular, files needed by `interpreter`). " +
            "The value of `interpreter` need not be included in this field. If " +
            "this is a platform runtime then this field is `None`."
        ),
        "interpreter": (
            "If this is an in-build runtime, this field is a `File` representing " +
            "the interpreter. Otherwise, this is `None`. Note that an in-build " +
            "runtime can use either a prebuilt, checked-in interpreter or an " +
            "interpreter built from source."
        ),
        "interpreter_path": (
            "If this is a platform runtime, this field is the absolute " +
            "filesystem path to the interpreter on the target platform. " +
            "Otherwise, this is `None`."
        ),
        "python_version": (
            "Indicates whether this runtime uses Python major version 2 or 3. " +
            "Valid values are (only) `\"PY2\"` and " +
            "`\"PY3\"`."
        ),
        "stub_shebang": (
            "\"Shebang\" expression prepended to the bootstrapping Python stub " +
            "script used when executing `py_binary` targets.  Does not " +
            "apply to Windows."
        ),
    },
)

def _check_arg_type(name, required_type, value):
    value_type = type(value)
    if value_type != required_type:
        fail("parameter '{}' got value of type '{}', want '{}'".format(
            name,
            value_type,
            required_type,
        ))

def _PyInfo_init(
        *,
        transitive_sources,
        uses_shared_libraries = False,
        imports = depset(),
        has_py2_only_sources = False,
        has_py3_only_sources = False):
    _check_arg_type("transitive_sources", "depset", transitive_sources)

    # Verify it's postorder compatible, but retain is original ordering.
    depset(transitive = [transitive_sources], order = "postorder")

    _check_arg_type("uses_shared_libraries", "bool", uses_shared_libraries)
    _check_arg_type("imports", "depset", imports)
    _check_arg_type("has_py2_only_sources", "bool", has_py2_only_sources)
    _check_arg_type("has_py3_only_sources", "bool", has_py3_only_sources)
    return {
        "has_py2_only_sources": has_py2_only_sources,
        "has_py3_only_sources": has_py2_only_sources,
        "imports": imports,
        "transitive_sources": transitive_sources,
        "uses_shared_libraries": uses_shared_libraries,
    }

PyInfo, _unused_raw_py_info_ctor = _define_provider(
    doc = "Encapsulates information provided by the Python rules.",
    init = _PyInfo_init,
    fields = {
        "has_py2_only_sources": "Whether any of this target's transitive sources requires a Python 2 runtime.",
        "has_py3_only_sources": "Whether any of this target's transitive sources requires a Python 3 runtime.",
        "imports": """\
A depset of import path strings to be added to the `PYTHONPATH` of executable
Python targets. These are accumulated from the transitive `deps`.
The order of the depset is not guaranteed and may be changed in the future. It
is recommended to use `default` order (the default).
""",
        "transitive_sources": """\
A (`postorder`-compatible) depset of `.py` files appearing in the target's
`srcs` and the `srcs` of the target's transitive `deps`.
""",
        "uses_shared_libraries": """
Whether any of this target's transitive `deps` has a shared library file (such
as a `.so` file).

This field is currently unused in Bazel and may go away in the future.
""",
    },
)

def _PyCcLinkParamsProvider_init(cc_info):
    return {
        "cc_info": _CcInfo(linking_context = cc_info.linking_context),
    }

# buildifier: disable=name-conventions
PyCcLinkParamsProvider, _unused_raw_py_cc_link_params_provider_ctor = _define_provider(
    doc = ("Python-wrapper to forward CcInfo.linking_context. This is to " +
           "allow Python targets to propagate C++ linking information, but " +
           "without the Python target appearing to be a valid C++ rule dependency"),
    init = _PyCcLinkParamsProvider_init,
    fields = {
        "cc_info": "A CcInfo instance; it has only linking_context set",
    },
)
