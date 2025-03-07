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
"""Common code for implementing py_library rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(
    ":attributes.bzl",
    "COMMON_ATTRS",
    "IMPORTS_ATTRS",
    "PY_SRCS_ATTRS",
    "PrecompileAttr",
    "REQUIRED_EXEC_GROUPS",
    "SRCS_VERSION_ALL_VALUES",
    "create_srcs_attr",
    "create_srcs_version_attr",
)
load(":builders.bzl", "builders")
load(
    ":common.bzl",
    "PYTHON_FILE_EXTENSIONS",
    "collect_imports",
    "collect_runfiles",
    "create_instrumented_files_info",
    "create_output_group_info",
    "create_py_info",
    "filter_to_py_srcs",
    "runfiles_root_path",
    "union_attrs",
)
load(":flags.bzl", "AddSrcsToRunfilesFlag", "PrecompileFlag")
load(":py_cc_link_params_info.bzl", "PyCcLinkParamsInfo")
load(":py_internal.bzl", "py_internal")
load(
    ":toolchain_types.bzl",
    "EXEC_TOOLS_TOOLCHAIN_TYPE",
    TOOLCHAIN_TYPE = "TARGET_TOOLCHAIN_TYPE",
)

_py_builtins = py_internal

LIBRARY_ATTRS = union_attrs(
    COMMON_ATTRS,
    PY_SRCS_ATTRS,
    IMPORTS_ATTRS,
    create_srcs_version_attr(values = SRCS_VERSION_ALL_VALUES),
    create_srcs_attr(mandatory = False),
    {
        "site_packages_root": attr.string(
            doc = """
Package relative prefix to remove from `srcs` for site-packages layouts.

This attribute is mutually exclusive with the {attr}`imports` attribute.

When set, `srcs` are interpreted to have a file layout as if they were installed
in site-packages. This attribute specifies the directory within `srcs` to treat
as the site-packages root so the correct site-packages relative paths for
the files can be computed.

:::{note}
This string is relative to the target's *Bazel package*. e.g. Relative to the
directory with the BUILD file that defines the target (the same as how e.g.
`srcs`).
:::

For example, given `srcs=["site-packages/foo/bar.py"]`, specifying
`site_packages_root="site-packages/" means `foo/bar.py` is the file path
under the binary's venv site-packages directory that should be made available.

`__init__.py` files are treated specially to provide basic support for [implicit
namespace packages](
https://packaging.python.org/en/latest/guides/packaging-namespace-packages/#native-namespace-packages).
However, the *content* of the files cannot be taken into account, merely their
presence or absense. Stated another way: [pkgutil-style namespace packages](
https://packaging.python.org/en/latest/guides/packaging-namespace-packages/#pkgutil-style-namespace-packages)
won't be understood as namespace packages; they'll be seen as regular packages. This will
likely lead to conflicts with other targets that contribute to the namespace.

:::{tip}
This attributes populates {obj}`PyInfo.site_packages_symlinks`, which is
a topologically ordered depset. This means dependencies closer and earlier
to a consumer have precedence. See {obj}`PyInfo.site_packages_symlinks` for
more information.
:::

:::{versionadded} VERSION_NEXT_FEATURE
:::
""",
        ),
        "_add_srcs_to_runfiles_flag": attr.label(
            default = "//python/config_settings:add_srcs_to_runfiles",
        ),
    },
)

def py_library_impl(ctx, *, semantics):
    """Abstract implementation of py_library rule.

    Args:
        ctx: The rule ctx
        semantics: A `LibrarySemantics` struct; see `create_library_semantics_struct`

    Returns:
        A list of modern providers to propagate.
    """
    direct_sources = filter_to_py_srcs(ctx.files.srcs)

    precompile_result = semantics.maybe_precompile(ctx, direct_sources)

    required_py_files = precompile_result.keep_srcs
    required_pyc_files = []
    implicit_pyc_files = []
    implicit_pyc_source_files = direct_sources

    precompile_attr = ctx.attr.precompile
    precompile_flag = ctx.attr._precompile_flag[BuildSettingInfo].value
    if (precompile_attr == PrecompileAttr.ENABLED or
        precompile_flag == PrecompileFlag.FORCE_ENABLED):
        required_pyc_files.extend(precompile_result.pyc_files)
    else:
        implicit_pyc_files.extend(precompile_result.pyc_files)

    default_outputs = builders.DepsetBuilder()
    default_outputs.add(precompile_result.keep_srcs)
    default_outputs.add(required_pyc_files)
    default_outputs = default_outputs.build()

    runfiles = builders.RunfilesBuilder()
    if AddSrcsToRunfilesFlag.is_enabled(ctx):
        runfiles.add(required_py_files)
    runfiles.add(collect_runfiles(ctx))
    runfiles = runfiles.build(ctx)

    imports = []
    site_packages_symlinks = []
    if ctx.attr.imports and ctx.attr.site_packages_root:
        fail(("Only one of the `imports` or `site_packages_root` attributes " +
              "can be set: site_packages_root={}, imports={}").format(
            ctx.attr.site_packages_root,
            ctx.attr.imports,
        ))
    elif ctx.attr.site_packages_root:
        site_packages_symlinks = _get_site_packages_symlinks(ctx)
    elif ctx.attr.imports:
        imports = collect_imports(ctx, semantics)

    cc_info = semantics.get_cc_info_for_library(ctx)
    py_info, deps_transitive_sources, builtins_py_info = create_py_info(
        ctx,
        original_sources = direct_sources,
        required_py_files = required_py_files,
        required_pyc_files = required_pyc_files,
        implicit_pyc_files = implicit_pyc_files,
        implicit_pyc_source_files = implicit_pyc_source_files,
        imports = imports,
        site_packages_symlinks = site_packages_symlinks,
    )

    # TODO(b/253059598): Remove support for extra actions; https://github.com/bazelbuild/bazel/issues/16455
    listeners_enabled = _py_builtins.are_action_listeners_enabled(ctx)
    if listeners_enabled:
        _py_builtins.add_py_extra_pseudo_action(
            ctx = ctx,
            dependency_transitive_python_sources = deps_transitive_sources,
        )

    providers = [
        DefaultInfo(files = default_outputs, runfiles = runfiles),
        py_info,
        create_instrumented_files_info(ctx),
        PyCcLinkParamsInfo(cc_info = cc_info),
        create_output_group_info(py_info.transitive_sources, extra_groups = {}),
    ]
    if builtins_py_info:
        providers.append(builtins_py_info)
    return providers

_DEFAULT_PY_LIBRARY_DOC = """
A library of Python code that can be depended upon.

Default outputs:
* The input Python sources
* The precompiled artifacts from the sources.

NOTE: Precompilation affects which of the default outputs are included in the
resulting runfiles. See the precompile-related attributes and flags for
more information.

:::{versionchanged} 0.37.0
Source files are no longer added to the runfiles directly.
:::
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

    # TODO: b/253818097 - fragments=py is only necessary so that
    # RequiredConfigFragmentsTest passes
    fragments = kwargs.pop("fragments", None) or []
    kwargs["exec_groups"] = REQUIRED_EXEC_GROUPS | (kwargs.get("exec_groups") or {})
    return rule(
        attrs = dicts.add(LIBRARY_ATTRS, attrs),
        toolchains = [
            config_common.toolchain_type(TOOLCHAIN_TYPE, mandatory = False),
            config_common.toolchain_type(EXEC_TOOLS_TOOLCHAIN_TYPE, mandatory = False),
        ],
        fragments = fragments + ["py"],
        **kwargs
    )

def _get_site_packages_symlinks(ctx):
    if not ctx.attr.site_packages_root:
        return []

    # We have to build a list of (runfiles path, site-packages path) pairs of
    # the files to create in the consuming binary's venv site-packages directory.
    # To minimize the number of files to create, we just return the paths
    # to the directories containing the code of interest.
    #
    # However, namespace packages complicate matters: multiple
    # distributions install in the same directory in site-packages. This
    # works out because they don't overlap in their files. Typically, they
    # install to different directories within the namespace package
    # directory. Namespace package directories are simply directories
    # within site-packages that *don't* have an `__init__.py` file, which
    # can be arbitrarily deep. Thus, we simply have to look for the
    # directories that _do_ have an `__init__.py` file and treat those as
    # the path to symlink to.

    site_packages_root = paths.join(ctx.label.package, ctx.attr.site_packages_root)
    repo_runfiles_dirname = None
    dirs_with_init = {}  # dirname -> runfile path
    for src in ctx.files.srcs:
        if src.extension not in PYTHON_FILE_EXTENSIONS:
            continue
        path = _repo_relative_short_path(src.short_path)
        if not path.startswith(site_packages_root):
            continue
        path = path.removeprefix(site_packages_root)
        dir_name, _, filename = path.rpartition("/")
        if not dir_name:
            # This would be e.g. `site-packages/__init__.py`, which isn't valid.
            # Apparently, the pypi integration adds such a file?
            continue

        if filename.startswith("__init__."):
            dirs_with_init[dir_name] = None
            repo_runfiles_dirname = runfiles_root_path(ctx, src.short_path).partition("/")[0]

    # Sort so that we encounter `foo` before `foo/bar`. This ensures we
    # see the top-most explicit package first.
    dirnames = sorted(dirs_with_init.keys())
    first_level_explicit_packages = []
    for d in dirnames:
        is_sub_package = False
        for existing in first_level_explicit_packages:
            # Suffix with / to prevent foo matching foobar
            if d.startswith(existing + "/"):
                is_sub_package = True
                break
        if not is_sub_package:
            first_level_explicit_packages.append(d)

    site_packages_symlinks = []
    for dirname in first_level_explicit_packages:
        site_packages_symlinks.append((
            paths.join(repo_runfiles_dirname, site_packages_root, dirname),
            dirname,
        ))
    return site_packages_symlinks

def _repo_relative_short_path(short_path):
    if short_path.startswith("../"):
        return short_path[3:].partition("/")[2]
    else:
        return short_path
