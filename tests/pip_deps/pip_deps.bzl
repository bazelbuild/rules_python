""" A demo implementation for pip_deps which provides @unpinned_pip//:pin. """

load("@rules_python//python:pip.bzl", "pip_install")

def _requirements_in_impl(repository_ctx):
    repository_ctx.file(
        "requirements.in",
        content = "".join(["{package} == {version}\n".format(
            package = package,
            version = version,
        ) for (package, version) in repository_ctx.attr.packages.items()]),
    )
    repository_ctx.file("WORKSPACE", content = "")
    repository_ctx.file("BUILD", content = """
load("@rules_python//python:pip.bzl", "compile_pip_requirements")

compile_pip_requirements(
    name = "pin",
    extra_args = ["--allow-unsafe"],
    requirements_in = "requirements.in",
    requirements_txt = "@{workspace_name}//{package}:{name}",
)
""".format(
        workspace_name = repository_ctx.attr.requirements_lock.workspace_name,
        package = repository_ctx.attr.requirements_lock.package,
        name = repository_ctx.attr.requirements_lock.name,
    ))

_requirements_in = repository_rule(
    implementation = _requirements_in_impl,
    attrs = {
        "packages": attr.string_dict(),
        "requirements_lock": attr.label(allow_single_file = True),
    },
)

def pip_deps(
        *,
        name = "pip",
        packages = {},
        requirements_lock_target = Label("//:requirements_txt"),
        requirements_lock_file = Label("//:requirements.txt"),
        python_interpreter_target = None,
        **kwargs):
    _requirements_in(
        name = "unpinned_" + name,
        packages = packages,
        requirements_lock = requirements_lock_target,
    )
    pip_install(
        name = name,
        requirements_lock = requirements_lock_file,
        python_interpreter_target = python_interpreter_target,
        **kwargs
    )
