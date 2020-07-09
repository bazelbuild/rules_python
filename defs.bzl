load("//:repositories.bzl", "all_requirements")

DEFAULT_REPOSITORY_NAME = "pip"

def _pip_repository_impl(rctx):
    python_interpreter = rctx.attr.python_interpreter
    if rctx.attr.python_interpreter_target != None:
        target = rctx.attr.python_interpreter_target
        python_interpreter = rctx.path(target)
    else:
        if "/" not in python_interpreter:
            python_interpreter = rctx.which(python_interpreter)
        if not python_interpreter:
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

    args = [
        python_interpreter,
        "-m",
        "extract_wheels",
        "--requirements",
        rctx.path(rctx.attr.requirements),
        "--repo",
        "@%s" % rctx.attr.name,
    ]

    if rctx.attr.extra_pip_args:
        args += [
            "--extra_pip_args",
            "\"" + " ".join(rctx.attr.extra_pip_args) + "\"",
        ]

    if rctx.attr.pip_data_exclude:
        args += [
            "--pip_data_exclude",
            struct(exclude = rctx.attr.pip_data_exclude).to_json(),
        ]

    result = rctx.execute(
        args,
        environment = {
            # Manually construct the PYTHONPATH since we cannot use the toolchain here
            "PYTHONPATH": pypath,
        },
        timeout = rctx.attr.timeout,
        quiet = rctx.attr.quiet,
    )
    if result.return_code:
        fail("rules_python_external failed: %s (%s)" % (result.stdout, result.stderr))

    return

pip_repository = repository_rule(
    attrs = {
        "requirements": attr.label(allow_single_file = True, mandatory = True),
        "wheel_env": attr.string_dict(),
        "python_interpreter": attr.string(default = "python3"),
        "python_interpreter_target": attr.label(allow_single_file = True, doc = """
If you are using a custom python interpreter built by another repository rule,
use this attribute to specify its BUILD target. This allows pip_repository to invoke
pip using the same interpreter as your toolchain. If set, takes precedence over
python_interpreter.
"""),
        # 600 is documented as default here: https://docs.bazel.build/versions/master/skylark/lib/repository_ctx.html#execute
        "timeout": attr.int(default = 600),
        "quiet": attr.bool(default = True),
        "extra_pip_args": attr.string_list(
            doc = "Extra arguments to pass on to pip. Must not contain spaces.",
        ),
        "pip_data_exclude": attr.string_list(
            doc = "Additional data exclusion parameters to add to the pip packages BUILD file.",
        ),
    },
    implementation = _pip_repository_impl,
)

def pip_install(requirements, name = DEFAULT_REPOSITORY_NAME, **kwargs):
    pip_repository(
        name = name,
        requirements = requirements,
        **kwargs
    )
