load("@bazel_skylib//lib:paths.bzl", "paths")

PyWheel = provider()
PyExtractedWheel = provider()

def _runfiles_path(path, workspace_name):
    """Given a path, prepend the workspace name as the parent directory"""

    # It feels like there should be an easier, less fragile way.
    if path.startswith("../"):
        # External workspace, for example
        # '../protobuf/python/google/protobuf/any_pb2.py'
        stored_path = path[len("../"):]
    elif path.startswith("external/"):
        # External workspace, for example
        # 'external/protobuf/python/__init__.py'
        stored_path = path[len("external/"):]
    else:
        # Main workspace, for example 'mypackage/main.py'
        stored_path = workspace_name + "/" + path

    return stored_path

def _runfiles_to_execroot_path(path, workspace_name):
    parts = path.split('/', 2)

    if parts[0] == workspace_name:
        return parts[1]
    
    return 'external/%s/%s' % (parts[0], parts[1])

def _merge_runfiles(base, *runfiles):
    for r in runfiles:
        base = base.merge(r)

    return base

def _expand_imports(ctx, imports):
    imports = imports.to_list()
    roots = ["", ctx.bin_dir.path, ctx.genfiles_dir.path]

    return depset(direct = [
        paths.join(root, _runfiles_to_execroot_path(imp, ctx.workspace_name))
        for imp in imports
        for root in roots
    ])

def _collect_sources(deps):
    py_deps = [
        dep[PyInfo]
        for dep in deps
        if PyInfo in dep
    ]

    sources = depset(transitive = [
        dep.transitive_sources for dep in py_deps
    ])

    imports = depset(transitive = [
        dep.imports for dep in py_deps
    ])

    wheels = depset(transitive = [
        dep[PyWheel].transitive_wheels
        for dep in deps
        if PyWheel in dep
    ])

    runfiles = [
        dep[DefaultInfo].default_runfiles
        for dep in deps
        if DefaultInfo in dep
    ]

    return struct(
        transitive_sources = sources,
        imports = imports,
        wheels = wheels,
        runfiles = runfiles,
    )

def _build_wheel(ctx, srcs=None, deps=None, build_deps=None):
    package_base = paths.join(
        ctx.label.workspace_root,
        ctx.label.package,
        ctx.attr.root,
    )

    for src in srcs:
        rel = paths.relativize(src.path, package_base)

        if rel.startswith("../"):
            fail("All files must be contained within %s (%s)" % (package_base, rel))

    wheels = ctx.actions.declare_directory("wheels")

    inputs = depset(
        direct = srcs,
        transitive = [
            deps.transitive_sources,
            deps.wheels,
            build_deps.transitive_sources,
            build_deps.wheels,
        ],
    )

    imports = _expand_imports(ctx, deps.imports)
    build_imports = _expand_imports(ctx, build_deps.imports)

    args = ctx.actions.args()
    args.add_all(deps.wheels, before_each = "--wheels")
    args.add_all(build_deps.wheels, before_each = "--wheels")
    args.add_all(imports, before_each = "--imports")
    args.add_all(build_imports, before_each = "--imports")
    args.add("--output", wheels.path)
    args.add(package_base)

    ctx.actions.run(
        executable = ctx.executable._build_wheel,
        inputs = inputs,
        outputs = [wheels],
        mnemonic = "PyBuildWheel",
        progress_message = "Building wheel for %s" % ctx.attr.name,
        arguments = [args],
        use_default_shell_env = True,
    )

    return wheels

def _extract_wheels(ctx, wheels):
    extracted = ctx.actions.declare_directory("packages")

    args = ctx.actions.args()
    args.add("--output", extracted.path)
    args.add_all(wheels)

    ctx.actions.run(
        executable = ctx.executable._extract_wheel,
        inputs = wheels,
        outputs = [extracted],
        mnemonic = "PyExtractWheel",
        progress_message = "Extracting wheel for %s" % ctx.attr.name,
        arguments = [args],
        use_default_shell_env = True,
    )

    return extracted

def _py_wheel_library_impl(ctx):
    deps = _collect_sources(ctx.attr.deps)
    build_deps = _collect_sources(ctx.attr.build_deps)

    built_wheels = _build_wheel(
        ctx,
        srcs = ctx.files.srcs,
        deps = deps,
        build_deps = build_deps,
    )
    
    extracted = _extract_wheels(ctx, [built_wheels])

    import_path = _runfiles_path(extracted.short_path, ctx.workspace_name)

    runfiles = ctx.runfiles(files = [extracted])
    runfiles = _merge_runfiles(runfiles, *deps.runfiles)

    return [
        DefaultInfo(
            files = depset(direct = [built_wheels]),
            runfiles = runfiles,
        ),
        PyInfo(
            transitive_sources = depset(
                direct = [extracted],
                transitive = [deps.transitive_sources],
            ),
            imports = depset(
                direct = [import_path],
                transitive = [deps.imports],
            ),
        ),
        PyWheel(
            transitive_wheels = depset(
                direct = [built_wheels],
                transitive = [deps.wheels],
            ),
        ),
    ]

py_wheel_library = rule(
    implementation = _py_wheel_library_impl,
    attrs = {
        "root": attr.string(),
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "deps": attr.label_list(),
        "build_deps": attr.label_list(),
        "data": attr.label_list(
            allow_files = True,
        ),
        "_build_wheel": attr.label(
            executable = True,
            allow_single_file = True,
            default = Label("//tools/prebuilt:build_wheel.par"),
            cfg = "exec",
        ),
        "_extract_wheel": attr.label(
            executable = True,
            allow_single_file = True,
            default = Label("//tools/prebuilt:extract_wheel.par"),
            cfg = "exec",
        ),
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
    },
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "@bazel_tools//tools/python:toolchain_type",
    ],
    fragments = ["cpp"]
)
