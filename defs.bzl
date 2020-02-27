load("//:repositories.bzl", "all_requirements")

DEFAULT_REPOSITORY_NAME = "pip"


def _pip_repository_impl(rctx):
    if not rctx.which(rctx.attr.python_interpreter):
        fail("python interpreter not found")

    rctx.file("BUILD", "")

    # Get the root directory of these rules
    rules_root = rctx.path(Label("//:BUILD")).dirname
    thirdparty_roots = [
        # Includes all the external dependencies from repositories.bzl
        rctx.path(Label("@" + repo + "//:BUILD.bazel")).dirname
        for repo in all_requirements
    ]
    pypath = ":".join([str(p) for p in [rules_root] + thirdparty_roots])

    result = rctx.execute(
        [
            rctx.which(rctx.attr.python_interpreter),
            rctx.path(rctx.attr._script).dirname,
            "--requirements",
            rctx.path(rctx.attr.requirements),
            "--repo",
            "@%s" % rctx.attr.name,
        ],
        environment={
            # Manually construct the PYTHONPATH since we cannot use the toolchain here
            "PYTHONPATH": pypath
        },
        timeout=rctx.attr.timeout,
    )
    if result.return_code:
        fail("rules_python_external failed: %s (%s)" % (result.stdout, result.stderr))

    return


pip_repository = repository_rule(
    attrs={
        "requirements": attr.label(allow_single_file=True, mandatory=True,),
        "wheel_env": attr.string_dict(),
        "python_interpreter": attr.string(default="python3"),
        "timeout": attr.int(default = 600),
        "_script": attr.label(
            executable=True, default=Label("//src:__main__.py"), cfg="host",
        ),
    },
    implementation=_pip_repository_impl,
)


def pip_install(requirements, name=DEFAULT_REPOSITORY_NAME):
    pip_repository(
        name=name, requirements=requirements,
    )
