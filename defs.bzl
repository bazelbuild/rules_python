def _pip_repository_impl(rctx):
    if not rctx.which(rctx.attr.python_interpreter):
        fail("python interpreter not found")

    rctx.file("BUILD", "")

    result = rctx.execute(
        [
            rctx.which(rctx.attr.python_interpreter),
            rctx.path(rctx.attr._script),
            "--requirements",
            rctx.path(rctx.attr.requirements),
            "--repo",
            "@%s" % rctx.attr.name,
        ],

        environment = rctx.attr.wheel_env,
    )
    if result.return_code:
        fail("failed to create pip repository: %s (%s)" % (result.stdout, result.stderr))

    return


pip_repository = repository_rule(
    attrs={
        "requirements": attr.label(allow_single_file=True, mandatory=True,),
        "wheel_env": attr.string_dict(),
        "python_interpreter": attr.string(default="python3"),
        "_script": attr.label(
            executable=True,
            default=Label("//tools:wheel_wrapper.py"),
            cfg="host",
        ),
    },
    implementation=_pip_repository_impl,
)
