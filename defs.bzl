def _pip_repository_impl(rctx):
    if not rctx.which("python3"):
        fail("python not found")

    rctx.file("BUILD", "")

    result = rctx.execute(
        [
            rctx.which("python3"),
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
        "_script": attr.label(
            executable=True,
            default=Label("//tools:wheel_wrapper.py"),
            cfg="host",
        ),
    },
    local=False,
    implementation=_pip_repository_impl,
)
