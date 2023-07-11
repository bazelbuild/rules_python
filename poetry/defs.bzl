"""Repository rule that can export a poetry.lock to a requirements.txt for the host platform

(or the exec platform, if you're using RBE-hosted repo rule execution?)
"""

def _poetry_export_impl(rctx):
    # FIXME: this doesn't work!!
    bin = rctx.path(rctx.attr.poetry_bin)
    cmd = [bin, "export"]

    for group in rctx.attr.groups:
        cmd.append("--with=" + group)

    result = rctx.execute(
        cmd,
        working_directory = str(rctx.path(rctx.attr.lockfile).dirname),
    )

    if result.return_code != 0:
        fail("Failed to execute poetry. Error: ", result.stderr)

    rctx.file("requirements_lock.txt", result.stdout)
    rctx.file("BUILD", "# no targets")

poetry_export = repository_rule(
    implementation = _poetry_export_impl,
    attrs = {
        "groups": attr.string_list(default = ["dev"]),
        "lockfile": attr.label(allow_single_file = [".lock"], mandatory = True),
        "poetry_bin": attr.label(default = "@poetry_poetry//:bin"),
    },
)
