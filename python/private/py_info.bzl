# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Implementation of PyInfo provider and PyInfo-specific utilities."""

load("@rules_python_internal//:rules_python_config.bzl", "config")
load(":builders.bzl", "builders")
load(":reexports.bzl", "BuiltinPyInfo")
load(":util.bzl", "define_bazel_6_provider")

def _check_arg_type(name, required_type, value):
    """Check that a value is of an expected type."""
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
        has_py3_only_sources = False,
        direct_pyc_files = depset(),
        transitive_pyc_files = depset(),
        transitive_implicit_pyc_files = depset(),
        transitive_implicit_pyc_source_files = depset()):
    _check_arg_type("transitive_sources", "depset", transitive_sources)

    # Verify it's postorder compatible, but retain is original ordering.
    depset(transitive = [transitive_sources], order = "postorder")

    _check_arg_type("uses_shared_libraries", "bool", uses_shared_libraries)
    _check_arg_type("imports", "depset", imports)
    _check_arg_type("has_py2_only_sources", "bool", has_py2_only_sources)
    _check_arg_type("has_py3_only_sources", "bool", has_py3_only_sources)
    _check_arg_type("direct_pyc_files", "depset", direct_pyc_files)
    _check_arg_type("transitive_pyc_files", "depset", transitive_pyc_files)

    _check_arg_type("transitive_implicit_pyc_files", "depset", transitive_pyc_files)
    _check_arg_type("transitive_implicit_pyc_source_files", "depset", transitive_pyc_files)
    return {
        "direct_pyc_files": direct_pyc_files,
        "has_py2_only_sources": has_py2_only_sources,
        "has_py3_only_sources": has_py2_only_sources,
        "imports": imports,
        "transitive_implicit_pyc_files": transitive_implicit_pyc_files,
        "transitive_implicit_pyc_source_files": transitive_implicit_pyc_source_files,
        "transitive_pyc_files": transitive_pyc_files,
        "transitive_sources": transitive_sources,
        "uses_shared_libraries": uses_shared_libraries,
    }

PyInfo, _unused_raw_py_info_ctor = define_bazel_6_provider(
    doc = "Encapsulates information provided by the Python rules.",
    init = _PyInfo_init,
    fields = {
        "direct_pyc_files": """
:type: depset[File]

Precompiled Python files that are considered directly provided
by the target and **must be included**.

These files usually come from, e.g., a library setting {attr}`precompile=enabled`
to forcibly enable precompiling for itself. Downstream binaries are expected
to always include these files, as the originating target expects them to exist.
""",
        "has_py2_only_sources": """
:type: bool

Whether any of this target's transitive sources requires a Python 2 runtime.
""",
        "has_py3_only_sources": """
:type: bool

Whether any of this target's transitive sources requires a Python 3 runtime.
""",
        "imports": """\
:type: depset[str]

A depset of import path strings to be added to the `PYTHONPATH` of executable
Python targets. These are accumulated from the transitive `deps`.
The order of the depset is not guaranteed and may be changed in the future. It
is recommended to use `default` order (the default).
""",
        "transitive_implicit_pyc_files": """
:type: depset[File]

Automatically generated pyc files that downstream binaries (or equivalent)
can choose to include in their output. If not included, then
{obj}`transitive_implicit_pyc_source_files` should be included instead.

::::{versionadded} 0.37.0
::::
""",
        "transitive_implicit_pyc_source_files": """
:type: depset[File]

Source `.py` files for {obj}`transitive_implicit_pyc_files` that downstream
binaries (or equivalent) can choose to include in their output. If not included,
then {obj}`transitive_implicit_pyc_files` should be included instead.

::::{versionadded} 0.37.0
::::
""",
        "transitive_pyc_files": """
:type: depset[File]

The transitive set of precompiled files that must be included.

These files usually come from, e.g., a library setting {attr}`precompile=enabled`
to forcibly enable precompiling for itself. Downstream binaries are expected
to always include these files, as the originating target expects them to exist.
""",
        "transitive_sources": """\
:type: depset[File]

A (`postorder`-compatible) depset of `.py` files that are considered required
and downstream binaries (or equivalent) **must** include in their outputs
to have a functioning program.

Normally, these are the `.py` files in the appearing in the target's `srcs` and
the `srcs` of the target's transitive `deps`, **however**, precompile settings
may cause `.py` files to be omitted. In particular, pyc-only builds may result
in this depset being **empty**.

::::{versionchanged} 0.37.0
The files are considered necessary for downstream binaries to function;
previously they were considerd informational and largely unused.
::::
""",
        "uses_shared_libraries": """
:type: bool

Whether any of this target's transitive `deps` has a shared library file (such
as a `.so` file).

This field is currently unused in Bazel and may go away in the future.
""",
    },
)

# The "effective" PyInfo is what the canonical //python:py_info.bzl%PyInfo symbol refers to
_EffectivePyInfo = PyInfo if (config.enable_pystar or BuiltinPyInfo == None) else BuiltinPyInfo

def PyInfoBuilder():
    # buildifier: disable=uninitialized
    self = struct(
        _has_py2_only_sources = [False],
        _has_py3_only_sources = [False],
        _uses_shared_libraries = [False],
        build = lambda *a, **k: _PyInfoBuilder_build(self, *a, **k),
        build_builtin_py_info = lambda *a, **k: _PyInfoBuilder_build_builtin_py_info(self, *a, **k),
        direct_pyc_files = builders.DepsetBuilder(),
        get_has_py2_only_sources = lambda *a, **k: _PyInfoBuilder_get_has_py2_only_sources(self, *a, **k),
        get_has_py3_only_sources = lambda *a, **k: _PyInfoBuilder_get_has_py3_only_sources(self, *a, **k),
        get_uses_shared_libraries = lambda *a, **k: _PyInfoBuilder_get_uses_shared_libraries(self, *a, **k),
        imports = builders.DepsetBuilder(),
        merge = lambda *a, **k: _PyInfoBuilder_merge(self, *a, **k),
        merge_all = lambda *a, **k: _PyInfoBuilder_merge_all(self, *a, **k),
        merge_has_py2_only_sources = lambda *a, **k: _PyInfoBuilder_merge_has_py2_only_sources(self, *a, **k),
        merge_has_py3_only_sources = lambda *a, **k: _PyInfoBuilder_merge_has_py3_only_sources(self, *a, **k),
        merge_target = lambda *a, **k: _PyInfoBuilder_merge_target(self, *a, **k),
        merge_targets = lambda *a, **k: _PyInfoBuilder_merge_targets(self, *a, **k),
        merge_uses_shared_libraries = lambda *a, **k: _PyInfoBuilder_merge_uses_shared_libraries(self, *a, **k),
        set_has_py2_only_sources = lambda *a, **k: _PyInfoBuilder_set_has_py2_only_sources(self, *a, **k),
        set_has_py3_only_sources = lambda *a, **k: _PyInfoBuilder_set_has_py3_only_sources(self, *a, **k),
        set_uses_shared_libraries = lambda *a, **k: _PyInfoBuilder_set_uses_shared_libraries(self, *a, **k),
        transitive_implicit_pyc_files = builders.DepsetBuilder(),
        transitive_implicit_pyc_source_files = builders.DepsetBuilder(),
        transitive_pyc_files = builders.DepsetBuilder(),
        transitive_sources = builders.DepsetBuilder(),
    )
    return self

def _PyInfoBuilder_get_has_py3_only_sources(self):
    return self._has_py3_only_sources[0]

def _PyInfoBuilder_get_has_py2_only_sources(self):
    return self._has_py2_only_sources[0]

def _PyInfoBuilder_set_has_py2_only_sources(self, value):
    self._has_py2_only_sources[0] = value
    return self

def _PyInfoBuilder_set_has_py3_only_sources(self, value):
    self._has_py3_only_sources[0] = value
    return self

def _PyInfoBuilder_merge_has_py2_only_sources(self, value):
    self._has_py2_only_sources[0] = self._has_py2_only_sources[0] or value
    return self

def _PyInfoBuilder_merge_has_py3_only_sources(self, value):
    self._has_py3_only_sources[0] = self._has_py3_only_sources[0] or value
    return self

def _PyInfoBuilder_merge_uses_shared_libraries(self, value):
    self._uses_shared_libraries[0] = self._uses_shared_libraries[0] or value
    return self

def _PyInfoBuilder_get_uses_shared_libraries(self):
    return self._uses_shared_libraries[0]

def _PyInfoBuilder_set_uses_shared_libraries(self, value):
    self._uses_shared_libraries[0] = value
    return self

def _PyInfoBuilder_merge(self, *infos, direct = []):
    return self.merge_all(list(infos), direct = direct)

def _PyInfoBuilder_merge_all(self, transitive, *, direct = []):
    for info in direct:
        # BuiltinPyInfo doesn't have this field
        if hasattr(info, "direct_pyc_files"):
            self.direct_pyc_files.add(info.direct_pyc_files)

    for info in direct + transitive:
        self.imports.add(info.imports)
        self.merge_has_py2_only_sources(info.has_py2_only_sources)
        self.merge_has_py3_only_sources(info.has_py3_only_sources)
        self.merge_uses_shared_libraries(info.uses_shared_libraries)
        self.transitive_sources.add(info.transitive_sources)

        # BuiltinPyInfo doesn't have these fields
        if hasattr(info, "transitive_pyc_files"):
            self.transitive_implicit_pyc_files.add(info.transitive_implicit_pyc_files)
            self.transitive_implicit_pyc_source_files.add(info.transitive_implicit_pyc_source_files)
            self.transitive_pyc_files.add(info.transitive_pyc_files)

    return self

def _PyInfoBuilder_merge_target(self, target):
    if PyInfo in target:
        self.merge(target[PyInfo])
    elif BuiltinPyInfo != None and BuiltinPyInfo in target:
        self.merge(target[BuiltinPyInfo])
    return self

def _PyInfoBuilder_merge_targets(self, targets):
    for t in targets:
        self.merge_target(t)
    return self

def _PyInfoBuilder_build(self):
    if config.enable_pystar:
        kwargs = dict(
            direct_pyc_files = self.direct_pyc_files.build(),
            transitive_pyc_files = self.transitive_pyc_files.build(),
            transitive_implicit_pyc_files = self.transitive_implicit_pyc_files.build(),
            transitive_implicit_pyc_source_files = self.transitive_implicit_pyc_source_files.build(),
        )
    else:
        kwargs = {}

    return _EffectivePyInfo(
        has_py2_only_sources = self._has_py2_only_sources[0],
        has_py3_only_sources = self._has_py3_only_sources[0],
        imports = self.imports.build(),
        transitive_sources = self.transitive_sources.build(),
        uses_shared_libraries = self._uses_shared_libraries[0],
        **kwargs
    )

def _PyInfoBuilder_build_builtin_py_info(self):
    if BuiltinPyInfo == None:
        return None

    return BuiltinPyInfo(
        has_py2_only_sources = self._has_py2_only_sources[0],
        has_py3_only_sources = self._has_py3_only_sources[0],
        imports = self.imports.build(),
        transitive_sources = self.transitive_sources.build(),
        uses_shared_libraries = self._uses_shared_libraries[0],
    )
