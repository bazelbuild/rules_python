
def _platform_transition_impl(settings, attr):
    return {
        "//command_line_option:platforms": str(attr.platform),
        "@rules_python//python/config_settings:python_version": attr.python_version.removeprefix("py"),
    }

_platform_transition = transition(
    implementation = _platform_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
        "@rules_python//python/config_settings:python_version",
    ],
)

def _transitioned_par_file_impl(ctx):
    files = ctx.attr.src[0][DefaultInfo].default_runfiles.files.to_list()
    out_file = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([file.path for file in files]),
    )
    return [DefaultInfo(
        files = depset([out_file]),
    )]

transitioned_par_file = rule(
    implementation = _transitioned_par_file_impl,
    attrs = {
        "src": attr.label(
            cfg = _platform_transition,
        ),
        "platform": attr.label(),
        "python_version": attr.string(),
    },
)
