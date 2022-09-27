"""Helper rules for demonstrating `py_wheel` examples"""

def _directory_writer_impl(ctx):
    output = ctx.actions.declare_directory(ctx.attr.out)

    args = ctx.actions.args()
    args.add("--output", output.path)

    for path, content in ctx.attr.files.items():
        args.add("--file={}={}".format(
            path,
            json.encode(content),
        ))

    ctx.actions.run(
        outputs = [output],
        arguments = [args],
        executable = ctx.executable._writer,
    )

    return [DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )]

directory_writer = rule(
    implementation = _directory_writer_impl,
    doc = "A rule for generating a directory with the requested content.",
    attrs = {
        "files": attr.string_dict(
            doc = "A mapping of file name to content to create relative to the generated `out` directory.",
        ),
        "out": attr.string(
            doc = "The name of the directory to create",
        ),
        "_writer": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//examples/wheel/private:directory_writer"),
        ),
    },
)
