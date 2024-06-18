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
"""Implementation of py_library rule."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//python/private:flags.bzl", "PrecompileAddToRunfilesFlag")
load(
    "//python/private:toolchain_types.bzl",
    "EXEC_TOOLS_TOOLCHAIN_TYPE",
    TOOLCHAIN_TYPE = "TARGET_TOOLCHAIN_TYPE",
)
load(
    ":attributes.bzl",
    "COMMON_ATTRS",
    "PY_SRCS_ATTRS",
    "SRCS_VERSION_ALL_VALUES",
    "create_srcs_attr",
    "create_srcs_version_attr",
)
load(
    ":common.bzl",
    "check_native_allowed",
    "collect_imports",
    "collect_runfiles",
    "create_instrumented_files_info",
    "create_output_group_info",
    "create_py_info",
    "filter_to_py_srcs",
    "union_attrs",
)
load(":providers.bzl", "PyCcLinkParamsProvider")
load(":py_internal.bzl", "py_internal")

_py_builtins = py_internal

LIBRARY_ATTRS = union_attrs(
    COMMON_ATTRS,
    PY_SRCS_ATTRS,
    create_srcs_version_attr(values = SRCS_VERSION_ALL_VALUES),
    create_srcs_attr(mandatory = False),
)

def py_library_impl(ctx, *, semantics):
    """Abstract implementation of py_library rule.

    Args:
        ctx: The rule ctx
        semantics: A `LibrarySemantics` struct; see `create_library_semantics_struct`

    Returns:
        A list of modern providers to propagate.
    """
    check_native_allowed(ctx)
    direct_sources = filter_to_py_srcs(ctx.files.srcs)
    precompile_result = semantics.maybe_precompile(ctx, direct_sources)
    direct_pyc_files = depset(precompile_result.pyc_files)
    default_outputs = depset(precompile_result.keep_srcs, transitive = [direct_pyc_files])

    extra_runfiles_depsets = [depset(precompile_result.keep_srcs)]
    if ctx.attr._precompile_add_to_runfiles_flag[BuildSettingInfo].value == PrecompileAddToRunfilesFlag.ALWAYS:
        extra_runfiles_depsets.append(direct_pyc_files)

    runfiles = collect_runfiles(
        ctx = ctx,
        files = depset(transitive = extra_runfiles_depsets),
    )

    cc_info = semantics.get_cc_info_for_library(ctx)
    py_info, deps_transitive_sources, builtins_py_info = create_py_info(
        ctx,
        direct_sources = depset(direct_sources),
        imports = collect_imports(ctx, semantics),
        direct_pyc_files = direct_pyc_files,
    )

    # TODO(b/253059598): Remove support for extra actions; https://github.com/bazelbuild/bazel/issues/16455
    listeners_enabled = _py_builtins.are_action_listeners_enabled(ctx)
    if listeners_enabled:
        _py_builtins.add_py_extra_pseudo_action(
            ctx = ctx,
            dependency_transitive_python_sources = deps_transitive_sources,
        )

    return [
        DefaultInfo(files = default_outputs, runfiles = runfiles),
        py_info,
        builtins_py_info,
        create_instrumented_files_info(ctx),
        PyCcLinkParamsProvider(cc_info = cc_info),
        create_output_group_info(py_info.transitive_sources, extra_groups = {}),
    ]

_DEFAULT_PY_LIBRARY_DOC = """
A library of Python code that can be depended upon.

Default outputs:
* The input Python sources
* The precompiled artifacts from the sources.

NOTE: Precompilation affects which of the default outputs are included in the
resulting runfiles. See the precompile-related attributes and flags for
more information.
"""

def create_py_library_rule(*, attrs = {}, **kwargs):
    """Creates a py_library rule.

    Args:
        attrs: dict of rule attributes.
        **kwargs: Additional kwargs to pass onto the rule() call.
    Returns:
        A rule object
    """

    # Within Google, the doc attribute is overridden
    kwargs.setdefault("doc", _DEFAULT_PY_LIBRARY_DOC)
    return rule(
        attrs = dicts.add(LIBRARY_ATTRS, attrs),
        toolchains = [
            config_common.toolchain_type(TOOLCHAIN_TYPE, mandatory = False),
            config_common.toolchain_type(EXEC_TOOLS_TOOLCHAIN_TYPE, mandatory = False),
        ],
        # TODO(b/253818097): fragments=py is only necessary so that
        # RequiredConfigFragmentsTest passes
        fragments = ["py"],
        **kwargs
    )
