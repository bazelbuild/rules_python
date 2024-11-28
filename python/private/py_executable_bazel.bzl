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
"""Implementation for Bazel Python executable."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(":attributes.bzl", "IMPORTS_ATTRS")
load(
    ":common.bzl",
    "create_binary_semantics_struct",
    "create_cc_details_struct",
    "create_executable_result_struct",
    "target_platform_has_any_constraint",
    "union_attrs",
)
load(":common_bazel.bzl", "collect_cc_info", "get_imports", "maybe_precompile")
load(":flags.bzl", "BootstrapImplFlag")
load(
    ":py_executable.bzl",
    "create_base_executable_rule",
    "py_executable_base_impl",
)
load(":py_internal.bzl", "py_internal")
load(":py_runtime_info.bzl", "DEFAULT_STUB_SHEBANG")
load(":toolchain_types.bzl", "TARGET_TOOLCHAIN_TYPE")

_py_builtins = py_internal
_EXTERNAL_PATH_PREFIX = "external"
_ZIP_RUNFILES_DIRECTORY_NAME = "runfiles"

BAZEL_EXECUTABLE_ATTRS = union_attrs(
    IMPORTS_ATTRS,
    {
        "legacy_create_init": attr.int(
            default = -1,
            values = [-1, 0, 1],
            doc = """\
Whether to implicitly create empty `__init__.py` files in the runfiles tree.
These are created in every directory containing Python source code or shared
libraries, and every parent directory of those directories, excluding the repo
root directory. The default, `-1` (auto), means true unless
`--incompatible_default_to_explicit_init_py` is used. If false, the user is
responsible for creating (possibly empty) `__init__.py` files and adding them to
the `srcs` of Python targets as required.
                                       """,
        ),
        "_bootstrap_template": attr.label(
            allow_single_file = True,
            default = "@bazel_tools//tools/python:python_bootstrap_template.txt",
        ),
        "_launcher": attr.label(
            cfg = "target",
            # NOTE: This is an executable, but is only used for Windows. It
            # can't have executable=True because the backing target is an
            # empty target for other platforms.
            default = "//tools/launcher:launcher",
        ),
        "_py_interpreter": attr.label(
            # The configuration_field args are validated when called;
            # we use the precense of py_internal to indicate this Bazel
            # build has that fragment and name.
            default = configuration_field(
                fragment = "bazel_py",
                name = "python_top",
            ) if py_internal else None,
        ),
        # TODO: This appears to be vestigial. It's only added because
        # GraphlessQueryTest.testLabelsOperator relies on it to test for
        # query behavior of implicit dependencies.
        "_py_toolchain_type": attr.label(
            default = TARGET_TOOLCHAIN_TYPE,
        ),
        "_python_version_flag": attr.label(
            default = "//python/config_settings:python_version",
        ),
        "_windows_launcher_maker": attr.label(
            default = "@bazel_tools//tools/launcher:launcher_maker",
            cfg = "exec",
            executable = True,
        ),
        "_zipper": attr.label(
            cfg = "exec",
            executable = True,
            default = "@bazel_tools//tools/zip:zipper",
        ),
    },
)

def create_executable_rule(*, attrs, **kwargs):
    return create_base_executable_rule(
        attrs = dicts.add(BAZEL_EXECUTABLE_ATTRS, attrs),
        fragments = ["py", "bazel_py"],
        **kwargs
    )

def py_executable_bazel_impl(ctx, *, is_test, inherited_environment):
    """Common code for executables for Bazel."""
    return py_executable_base_impl(
        ctx = ctx,
        semantics = create_binary_semantics_bazel(),
        is_test = is_test,
        inherited_environment = inherited_environment,
    )

def create_binary_semantics_bazel():
    return create_binary_semantics_struct(
        # keep-sorted start
        create_executable = _create_executable,
        get_cc_details_for_binary = _get_cc_details_for_binary,
        get_central_uncachable_version_file = lambda ctx: None,
        get_coverage_deps = _get_coverage_deps,
        get_debugger_deps = _get_debugger_deps,
        get_extra_common_runfiles_for_binary = lambda ctx: ctx.runfiles(),
        get_extra_providers = _get_extra_providers,
        get_extra_write_build_data_env = lambda ctx: {},
        get_imports = get_imports,
        get_interpreter_path = _get_interpreter_path,
        get_native_deps_dso_name = _get_native_deps_dso_name,
        get_native_deps_user_link_flags = _get_native_deps_user_link_flags,
        get_stamp_flag = _get_stamp_flag,
        maybe_precompile = maybe_precompile,
        should_build_native_deps_dso = lambda ctx: False,
        should_create_init_files = _should_create_init_files,
        should_include_build_data = lambda ctx: False,
        # keep-sorted end
    )

def _get_coverage_deps(ctx, runtime_details):
    _ = ctx, runtime_details  # @unused
    return []

def _get_debugger_deps(ctx, runtime_details):
    _ = ctx, runtime_details  # @unused
    return []

def _get_extra_providers(ctx, main_py, runtime_details):
    _ = ctx, main_py, runtime_details  # @unused
    return []

def _get_stamp_flag(ctx):
    # NOTE: Undocumented API; private to builtins
    return ctx.configuration.stamp_binaries

def _should_create_init_files(ctx):
    if ctx.attr.legacy_create_init == -1:
        return not ctx.fragments.py.default_to_explicit_init_py
    else:
        return bool(ctx.attr.legacy_create_init)

def _create_executable(
        ctx,
        *,
        executable,
        main_py,
        imports,
        is_test,
        runtime_details,
        cc_details,
        native_deps_details,
        runfiles_details):
    _ = is_test, cc_details, native_deps_details  # @unused

    is_windows = target_platform_has_any_constraint(ctx, ctx.attr._windows_constraints)

    if is_windows:
        if not executable.extension == "exe":
            fail("Should not happen: somehow we are generating a non-.exe file on windows")
        base_executable_name = executable.basename[0:-4]
    else:
        base_executable_name = executable.basename

    venv = None

    # The check for stage2_bootstrap_template is to support legacy
    # BuiltinPyRuntimeInfo providers, which is likely to come from
    # @bazel_tools//tools/python:autodetecting_toolchain, the toolchain used
    # for workspace builds when no rules_python toolchain is configured.
    if (BootstrapImplFlag.get_value(ctx) == BootstrapImplFlag.SCRIPT and
        runtime_details.effective_runtime and
        hasattr(runtime_details.effective_runtime, "stage2_bootstrap_template")):
        venv = _create_venv(
            ctx,
            output_prefix = base_executable_name,
            imports = imports,
            runtime_details = runtime_details,
        )

        stage2_bootstrap = _create_stage2_bootstrap(
            ctx,
            output_prefix = base_executable_name,
            output_sibling = executable,
            main_py = main_py,
            imports = imports,
            runtime_details = runtime_details,
        )
        extra_runfiles = ctx.runfiles([stage2_bootstrap] + venv.files_without_interpreter)
        zip_main = _create_zip_main(
            ctx,
            stage2_bootstrap = stage2_bootstrap,
            runtime_details = runtime_details,
            venv = venv,
        )
    else:
        stage2_bootstrap = None
        extra_runfiles = ctx.runfiles()
        zip_main = ctx.actions.declare_file(base_executable_name + ".temp", sibling = executable)
        _create_stage1_bootstrap(
            ctx,
            output = zip_main,
            main_py = main_py,
            imports = imports,
            is_for_zip = True,
            runtime_details = runtime_details,
        )

    zip_file = ctx.actions.declare_file(base_executable_name + ".zip", sibling = executable)
    _create_zip_file(
        ctx,
        output = zip_file,
        original_nonzip_executable = executable,
        zip_main = zip_main,
        runfiles = runfiles_details.default_runfiles.merge(extra_runfiles),
    )

    extra_files_to_build = []

    # NOTE: --build_python_zip defaults to true on Windows
    build_zip_enabled = ctx.fragments.py.build_python_zip

    # When --build_python_zip is enabled, then the zip file becomes
    # one of the default outputs.
    if build_zip_enabled:
        extra_files_to_build.append(zip_file)

    # The logic here is a bit convoluted. Essentially, there are 3 types of
    # executables produced:
    # 1. (non-Windows) A bootstrap template based program.
    # 2. (non-Windows) A self-executable zip file of a bootstrap template based program.
    # 3. (Windows) A native Windows executable that finds and launches
    #    the actual underlying Bazel program (one of the above). Note that
    #    it implicitly assumes one of the above is located next to it, and
    #    that --build_python_zip defaults to true for Windows.

    should_create_executable_zip = False
    bootstrap_output = None
    if not is_windows:
        if build_zip_enabled:
            should_create_executable_zip = True
        else:
            bootstrap_output = executable
    else:
        _create_windows_exe_launcher(
            ctx,
            output = executable,
            use_zip_file = build_zip_enabled,
            python_binary_path = runtime_details.executable_interpreter_path,
        )
        if not build_zip_enabled:
            # On Windows, the main executable has an "exe" extension, so
            # here we re-use the un-extensioned name for the bootstrap output.
            bootstrap_output = ctx.actions.declare_file(base_executable_name)

            # The launcher looks for the non-zip executable next to
            # itself, so add it to the default outputs.
            extra_files_to_build.append(bootstrap_output)

    if should_create_executable_zip:
        if bootstrap_output != None:
            fail("Should not occur: bootstrap_output should not be used " +
                 "when creating an executable zip")
        _create_executable_zip_file(
            ctx,
            output = executable,
            zip_file = zip_file,
            stage2_bootstrap = stage2_bootstrap,
            runtime_details = runtime_details,
            venv = venv,
        )
    elif bootstrap_output:
        _create_stage1_bootstrap(
            ctx,
            output = bootstrap_output,
            stage2_bootstrap = stage2_bootstrap,
            runtime_details = runtime_details,
            is_for_zip = False,
            imports = imports,
            main_py = main_py,
            venv = venv,
        )
    else:
        # Otherwise, this should be the Windows case of launcher + zip.
        # Double check this just to make sure.
        if not is_windows or not build_zip_enabled:
            fail(("Should not occur: The non-executable-zip and " +
                  "non-bootstrap-template case should have windows and zip " +
                  "both true, but got " +
                  "is_windows={is_windows} " +
                  "build_zip_enabled={build_zip_enabled}").format(
                is_windows = is_windows,
                build_zip_enabled = build_zip_enabled,
            ))

    # The interpreter is added this late in the process so that it isn't
    # added to the zipped files.
    if venv:
        extra_runfiles = extra_runfiles.merge(ctx.runfiles([venv.interpreter]))
    return create_executable_result_struct(
        extra_files_to_build = depset(extra_files_to_build),
        output_groups = {"python_zip_file": depset([zip_file])},
        extra_runfiles = extra_runfiles,
    )

def _create_zip_main(ctx, *, stage2_bootstrap, runtime_details, venv):
    python_binary = _runfiles_root_path(ctx, venv.interpreter.short_path)
    python_binary_actual = venv.interpreter_actual_path

    # The location of this file doesn't really matter. It's added to
    # the zip file as the top-level __main__.py file and not included
    # elsewhere.
    output = ctx.actions.declare_file(ctx.label.name + "_zip__main__.py")
    ctx.actions.expand_template(
        template = runtime_details.effective_runtime.zip_main_template,
        output = output,
        substitutions = {
            "%python_binary%": python_binary,
            "%python_binary_actual%": python_binary_actual,
            "%stage2_bootstrap%": "{}/{}".format(
                ctx.workspace_name,
                stage2_bootstrap.short_path,
            ),
            "%workspace_name%": ctx.workspace_name,
        },
    )
    return output

def relative_path(from_, to):
    """Compute a relative path from one path to another.

    Args:
        from_: {type}`str` the starting directory. Note that it should be
            a directory because relative-symlinks are relative to the
            directory the symlink resides in.
        to: {type}`str` the path that `from_` wants to point to

    Returns:
        {type}`str` a relative path
    """
    from_parts = from_.split("/")
    to_parts = to.split("/")

    # Strip common leading parts from both paths
    n = min(len(from_parts), len(to_parts))
    for _ in range(n):
        if from_parts[0] == to_parts[0]:
            from_parts.pop(0)
            to_parts.pop(0)
        else:
            break

    # Impossible to compute a relative path without knowing what ".." is
    if from_parts and from_parts[0] == "..":
        fail("cannot compute relative path from '%s' to '%s'", from_, to)

    parts = ([".."] * len(from_parts)) + to_parts
    return paths.join(*parts)

# Create a venv the executable can use.
# For venv details and the venv startup process, see:
# * https://docs.python.org/3/library/venv.html
# * https://snarky.ca/how-virtual-environments-work/
# * https://github.com/python/cpython/blob/main/Modules/getpath.py
# * https://github.com/python/cpython/blob/main/Lib/site.py
def _create_venv(ctx, output_prefix, imports, runtime_details):
    venv = "_{}.venv".format(output_prefix.lstrip("_"))

    # The pyvenv.cfg file must be present to trigger the venv site hooks.
    # Because it's paths are expected to be absolute paths, we can't reliably
    # put much in it. See https://github.com/python/cpython/issues/83650
    pyvenv_cfg = ctx.actions.declare_file("{}/pyvenv.cfg".format(venv))
    ctx.actions.write(pyvenv_cfg, "")

    runtime = runtime_details.effective_runtime
    if runtime.interpreter:
        py_exe_basename = paths.basename(runtime.interpreter.short_path)

        # Even though ctx.actions.symlink() is used, using
        # declare_symlink() is required to ensure that the resulting file
        # in runfiles is always a symlink. An RBE implementation, for example,
        # may choose to write what symlink() points to instead.
        interpreter = ctx.actions.declare_symlink("{}/bin/{}".format(venv, py_exe_basename))

        interpreter_actual_path = _runfiles_root_path(ctx, runtime.interpreter.short_path)
        rel_path = relative_path(
            # dirname is necessary because a relative symlink is relative to
            # the directory the symlink resides within.
            from_ = paths.dirname(_runfiles_root_path(ctx, interpreter.short_path)),
            to = interpreter_actual_path,
        )

        ctx.actions.symlink(output = interpreter, target_path = rel_path)
    else:
        py_exe_basename = paths.basename(runtime.interpreter_path)
        interpreter = ctx.actions.declare_symlink("{}/bin/{}".format(venv, py_exe_basename))
        ctx.actions.symlink(output = interpreter, target_path = runtime.interpreter_path)
        interpreter_actual_path = runtime.interpreter_path

    if runtime.interpreter_version_info:
        version = "{}.{}".format(
            runtime.interpreter_version_info.major,
            runtime.interpreter_version_info.minor,
        )
    else:
        version_flag = ctx.attr._python_version_flag[config_common.FeatureFlagInfo].value
        version_flag_parts = version_flag.split(".")[0:2]
        version = "{}.{}".format(*version_flag_parts)

    # See site.py logic: free-threaded builds append "t" to the venv lib dir name
    if "t" in runtime.abi_flags:
        version += "t"

    site_packages = "{}/lib/python{}/site-packages".format(venv, version)
    pth = ctx.actions.declare_file("{}/bazel.pth".format(site_packages))
    ctx.actions.write(pth, "import _bazel_site_init\n")

    site_init = ctx.actions.declare_file("{}/_bazel_site_init.py".format(site_packages))
    computed_subs = ctx.actions.template_dict()
    computed_subs.add_joined("%imports%", imports, join_with = ":", map_each = _map_each_identity)
    ctx.actions.expand_template(
        template = runtime.site_init_template,
        output = site_init,
        substitutions = {
            "%import_all%": "True" if ctx.fragments.bazel_py.python_import_all_repositories else "False",
            "%site_init_runfiles_path%": "{}/{}".format(ctx.workspace_name, site_init.short_path),
            "%workspace_name%": ctx.workspace_name,
        },
        computed_substitutions = computed_subs,
    )

    return struct(
        interpreter = interpreter,
        # Runfiles root relative path or absolute path
        interpreter_actual_path = interpreter_actual_path,
        files_without_interpreter = [pyvenv_cfg, pth, site_init],
    )

def _map_each_identity(v):
    return v

def _create_stage2_bootstrap(
        ctx,
        *,
        output_prefix,
        output_sibling,
        main_py,
        imports,
        runtime_details):
    output = ctx.actions.declare_file(
        # Prepend with underscore to prevent pytest from trying to
        # process the bootstrap for files starting with `test_`
        "_{}_stage2_bootstrap.py".format(output_prefix),
        sibling = output_sibling,
    )
    runtime = runtime_details.effective_runtime
    if (ctx.configuration.coverage_enabled and
        runtime and
        runtime.coverage_tool):
        coverage_tool_runfiles_path = "{}/{}".format(
            ctx.workspace_name,
            runtime.coverage_tool.short_path,
        )
    else:
        coverage_tool_runfiles_path = ""

    template = runtime.stage2_bootstrap_template

    ctx.actions.expand_template(
        template = template,
        output = output,
        substitutions = {
            "%coverage_tool%": coverage_tool_runfiles_path,
            "%import_all%": "True" if ctx.fragments.bazel_py.python_import_all_repositories else "False",
            "%imports%": ":".join(imports.to_list()),
            "%main%": "{}/{}".format(ctx.workspace_name, main_py.short_path),
            "%target%": str(ctx.label),
            "%workspace_name%": ctx.workspace_name,
        },
        is_executable = True,
    )
    return output

def _runfiles_root_path(ctx, short_path):
    """Compute a runfiles-root relative path from `File.short_path`

    Args:
        ctx: current target ctx
        short_path: str, a main-repo relative path from `File.short_path`

    Returns:
        {type}`str`, a runflies-root relative path
    """

    # The ../ comes from short_path is for files in other repos.
    if short_path.startswith("../"):
        return short_path[3:]
    else:
        return "{}/{}".format(ctx.workspace_name, short_path)

def _create_stage1_bootstrap(
        ctx,
        *,
        output,
        main_py = None,
        stage2_bootstrap = None,
        imports = None,
        is_for_zip,
        runtime_details,
        venv = None):
    runtime = runtime_details.effective_runtime

    if venv:
        python_binary_path = _runfiles_root_path(ctx, venv.interpreter.short_path)
    else:
        python_binary_path = runtime_details.executable_interpreter_path

    if is_for_zip and venv:
        python_binary_actual = venv.interpreter_actual_path
    else:
        python_binary_actual = ""

    subs = {
        "%is_zipfile%": "1" if is_for_zip else "0",
        "%python_binary%": python_binary_path,
        "%python_binary_actual%": python_binary_actual,
        "%target%": str(ctx.label),
        "%workspace_name%": ctx.workspace_name,
    }

    if stage2_bootstrap:
        subs["%stage2_bootstrap%"] = "{}/{}".format(
            ctx.workspace_name,
            stage2_bootstrap.short_path,
        )
        template = runtime.bootstrap_template
        subs["%shebang%"] = runtime.stub_shebang
    else:
        if (ctx.configuration.coverage_enabled and
            runtime and
            runtime.coverage_tool):
            coverage_tool_runfiles_path = "{}/{}".format(
                ctx.workspace_name,
                runtime.coverage_tool.short_path,
            )
        else:
            coverage_tool_runfiles_path = ""
        if runtime:
            subs["%shebang%"] = runtime.stub_shebang
            template = runtime.bootstrap_template
        else:
            subs["%shebang%"] = DEFAULT_STUB_SHEBANG
            template = ctx.file._bootstrap_template

        subs["%coverage_tool%"] = coverage_tool_runfiles_path
        subs["%import_all%"] = ("True" if ctx.fragments.bazel_py.python_import_all_repositories else "False")
        subs["%imports%"] = ":".join(imports.to_list())
        subs["%main%"] = "{}/{}".format(ctx.workspace_name, main_py.short_path)

    ctx.actions.expand_template(
        template = template,
        output = output,
        substitutions = subs,
    )

def _create_windows_exe_launcher(
        ctx,
        *,
        output,
        python_binary_path,
        use_zip_file):
    launch_info = ctx.actions.args()
    launch_info.use_param_file("%s", use_always = True)
    launch_info.set_param_file_format("multiline")
    launch_info.add("binary_type=Python")
    launch_info.add(ctx.workspace_name, format = "workspace_name=%s")
    launch_info.add(
        "1" if py_internal.runfiles_enabled(ctx) else "0",
        format = "symlink_runfiles_enabled=%s",
    )
    launch_info.add(python_binary_path, format = "python_bin_path=%s")
    launch_info.add("1" if use_zip_file else "0", format = "use_zip_file=%s")

    launcher = ctx.attr._launcher[DefaultInfo].files_to_run.executable
    ctx.actions.run(
        executable = ctx.executable._windows_launcher_maker,
        arguments = [launcher.path, launch_info, output.path],
        inputs = [launcher],
        outputs = [output],
        mnemonic = "PyBuildLauncher",
        progress_message = "Creating launcher for %{label}",
        # Needed to inherit PATH when using non-MSVC compilers like MinGW
        use_default_shell_env = True,
    )

def _create_zip_file(ctx, *, output, original_nonzip_executable, zip_main, runfiles):
    """Create a Python zipapp (zip with __main__.py entry point)."""
    workspace_name = ctx.workspace_name
    legacy_external_runfiles = _py_builtins.get_legacy_external_runfiles(ctx)

    manifest = ctx.actions.args()
    manifest.use_param_file("@%s", use_always = True)
    manifest.set_param_file_format("multiline")

    manifest.add("__main__.py={}".format(zip_main.path))
    manifest.add("__init__.py=")
    manifest.add(
        "{}=".format(
            _get_zip_runfiles_path("__init__.py", workspace_name, legacy_external_runfiles),
        ),
    )
    for path in runfiles.empty_filenames.to_list():
        manifest.add("{}=".format(_get_zip_runfiles_path(path, workspace_name, legacy_external_runfiles)))

    def map_zip_runfiles(file):
        if file != original_nonzip_executable and file != output:
            return "{}={}".format(
                _get_zip_runfiles_path(file.short_path, workspace_name, legacy_external_runfiles),
                file.path,
            )
        else:
            return None

    manifest.add_all(runfiles.files, map_each = map_zip_runfiles, allow_closure = True)

    inputs = [zip_main]
    if _py_builtins.is_bzlmod_enabled(ctx):
        zip_repo_mapping_manifest = ctx.actions.declare_file(
            output.basename + ".repo_mapping",
            sibling = output,
        )
        _py_builtins.create_repo_mapping_manifest(
            ctx = ctx,
            runfiles = runfiles,
            output = zip_repo_mapping_manifest,
        )
        manifest.add("{}/_repo_mapping={}".format(
            _ZIP_RUNFILES_DIRECTORY_NAME,
            zip_repo_mapping_manifest.path,
        ))
        inputs.append(zip_repo_mapping_manifest)

    for artifact in runfiles.files.to_list():
        # Don't include the original executable because it isn't used by the
        # zip file, so no need to build it for the action.
        # Don't include the zipfile itself because it's an output.
        if artifact != original_nonzip_executable and artifact != output:
            inputs.append(artifact)

    zip_cli_args = ctx.actions.args()
    zip_cli_args.add("cC")
    zip_cli_args.add(output)

    ctx.actions.run(
        executable = ctx.executable._zipper,
        arguments = [zip_cli_args, manifest],
        inputs = depset(inputs),
        outputs = [output],
        use_default_shell_env = True,
        mnemonic = "PythonZipper",
        progress_message = "Building Python zip: %{label}",
    )

def _get_zip_runfiles_path(path, workspace_name, legacy_external_runfiles):
    if legacy_external_runfiles and path.startswith(_EXTERNAL_PATH_PREFIX):
        zip_runfiles_path = paths.relativize(path, _EXTERNAL_PATH_PREFIX)
    else:
        # NOTE: External runfiles (artifacts in other repos) will have a leading
        # path component of "../" so that they refer outside the main workspace
        # directory and into the runfiles root. By normalizing, we simplify e.g.
        # "workspace/../foo/bar" to simply "foo/bar".
        zip_runfiles_path = paths.normalize("{}/{}".format(workspace_name, path))
    return "{}/{}".format(_ZIP_RUNFILES_DIRECTORY_NAME, zip_runfiles_path)

def _create_executable_zip_file(
        ctx,
        *,
        output,
        zip_file,
        stage2_bootstrap,
        runtime_details,
        venv):
    prelude = ctx.actions.declare_file(
        "{}_zip_prelude.sh".format(output.basename),
        sibling = output,
    )
    if stage2_bootstrap:
        _create_stage1_bootstrap(
            ctx,
            output = prelude,
            stage2_bootstrap = stage2_bootstrap,
            runtime_details = runtime_details,
            is_for_zip = True,
            venv = venv,
        )
    else:
        ctx.actions.write(prelude, "#!/usr/bin/env python3\n")

    ctx.actions.run_shell(
        command = "cat {prelude} {zip} > {output}".format(
            prelude = prelude.path,
            zip = zip_file.path,
            output = output.path,
        ),
        inputs = [prelude, zip_file],
        outputs = [output],
        use_default_shell_env = True,
        mnemonic = "PyBuildExecutableZip",
        progress_message = "Build Python zip executable: %{label}",
    )

def _get_cc_details_for_binary(ctx, extra_deps):
    cc_info = collect_cc_info(ctx, extra_deps = extra_deps)
    return create_cc_details_struct(
        cc_info_for_propagating = cc_info,
        cc_info_for_self_link = cc_info,
        cc_info_with_extra_link_time_libraries = None,
        extra_runfiles = ctx.runfiles(),
        # Though the rules require the CcToolchain, it isn't actually used.
        cc_toolchain = None,
        feature_config = None,
    )

def _get_interpreter_path(ctx, *, runtime, flag_interpreter_path):
    if runtime:
        if runtime.interpreter_path:
            interpreter_path = runtime.interpreter_path
        else:
            interpreter_path = "{}/{}".format(
                ctx.workspace_name,
                runtime.interpreter.short_path,
            )

            # NOTE: External runfiles (artifacts in other repos) will have a
            # leading path component of "../" so that they refer outside the
            # main workspace directory and into the runfiles root. By
            # normalizing, we simplify e.g. "workspace/../foo/bar" to simply
            # "foo/bar"
            interpreter_path = paths.normalize(interpreter_path)

    elif flag_interpreter_path:
        interpreter_path = flag_interpreter_path
    else:
        fail("Unable to determine interpreter path")

    return interpreter_path

def _get_native_deps_dso_name(ctx):
    _ = ctx  # @unused
    fail("Building native deps DSO not supported.")

def _get_native_deps_user_link_flags(ctx):
    _ = ctx  # @unused
    fail("Building native deps DSO not supported.")
