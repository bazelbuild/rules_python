load("@bazel_skylib//lib:paths.bzl", "paths")
load("//python:py_runtime_info.bzl", "PyRuntimeInfo")
load(":sentinel.bzl", "SentinelInfo")
load(":toolchain_types.bzl", "TARGET_TOOLCHAIN_TYPE")

def _interpreter_impl(ctx):
    if SentinelInfo in ctx.attr.binary:
        toolchain = ctx.toolchains[TARGET_TOOLCHAIN_TYPE]
        runtime = toolchain.py3_runtime
    else:
        runtime = ctx.attr.binary[PyRuntimeInfo]

    # NOTE: We name the output filename after the underlying file name
    # because of things like pyenv: they use $0 to determine what to
    # re-exec. If it's not a recognized name, then they fail.
    if runtime.interpreter:
        executable = ctx.actions.declare_file(runtime.interpreter.basename)
        ctx.actions.symlink(output = executable, target_file = runtime.interpreter, is_executable = True)
    else:
        executable = ctx.actions.declare_symlink(paths.basename(runtime.interpreter_path))
        ctx.actions.symlink(output = executable, target_path = runtime.interpreter_path)

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles([executable], transitive_files = runtime.files),
        ),
    ]

interpreter = rule(
    implementation = _interpreter_impl,
    toolchains = [TARGET_TOOLCHAIN_TYPE],
    executable = True,
    attrs = {
        "binary": attr.label(
            mandatory = True,
        ),
    },
)
