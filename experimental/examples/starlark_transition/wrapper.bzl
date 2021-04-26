# A transition and rule to set --python_version to the value specified by an
# attr. Unlike the native transition, this will cause a hash of the config to
# be appended to the output directory name.

def _py_transition_impl(settings, attr):
    return {"//command_line_option:python_version": attr.version}

_py_transition = transition(
    implementation = _py_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:python_version"],
)

def _py_wrapper_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.run_shell(
        tools = [ctx.executable.wrapped],
        outputs = [out],
        command = "cp %s %s" % (ctx.executable.wrapped.path, out.path),
        )

    wrapped_defaultinfo = ctx.attr.wrapped[0][DefaultInfo]
    default_runfiles = ctx.runfiles(files=[out])
    return [DefaultInfo(
        executable = out,
        default_runfiles = default_runfiles.merge(wrapped_defaultinfo.default_runfiles),
        data_runfiles = wrapped_defaultinfo.data_runfiles)]

py_wrapper = rule(
    implementation = _py_wrapper_impl,
    attrs = {
        "wrapped": attr.label(cfg = _py_transition, executable=True),
        "version": attr.string(values = ["PY2", "PY3"]),
        # Needed to allow Starlark-defined transitions. Not production-ready.
        "_whitelist_function_transition": attr.label(
            default = "@bazel_tools//tools/whitelists/function_transition_whitelist",
        ),
    },
    executable = True,
)
