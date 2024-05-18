"""Implementation of whl_filegroup rule."""

def _whl_filegroup_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.attr.name)
    ctx.actions.run(
        outputs = [out_dir],
        inputs = [ctx.file.whl],
        tools = [ctx.executable._extract_wheel_files_tool],
        arguments = [
            ctx.file.whl.path,
            out_dir.path,
            ctx.attr.pattern,
        ],
        executable = ctx.executable._extract_wheel_files_tool,
        mnemonic = "ExtractWheelFiles",
    )
    return [DefaultInfo(
        files = depset([out_dir]),
        runfiles = ctx.runfiles(files = [out_dir]),
    )]

whl_filegroup = rule(
    _whl_filegroup_impl,
    doc = "Extract files matching a regex pattern from a wheel file.",
    attrs = {
        "pattern": attr.string(default = "", doc = "Only files that match this pattern will be extracted."),
        "whl": attr.label(mandatory = True, allow_single_file = True, doc = "The wheel to extract files from."),
        "_extract_wheel_files_tool": attr.label(
            default = Label("//python/private/whl_filegroup:extract_wheel_files"),
            cfg = "exec",
            executable = True,
        ),
    },
)
