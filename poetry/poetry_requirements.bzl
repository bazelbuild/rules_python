"""Starlark representation of locked requirements.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_POETRY_VERSION = "1.5.1"

def poetry_repositories():
    # Avoid circular dependency with poetry_plugin_export
    # https://github.com/python-poetry/poetry/pull/5980
    # By fetching the top-level package outside of a whl_library
    http_archive(
        name = "poetry_poetry",
        sha256 = "dfc7ce3a38ae216c0465694e2e674bef6eb1a2ba81aa47a26f9dc03362fe2f5f",
        patch_args = ["-p1"],
        patches = ["@rules_python//poetry:poetry_wheel.patch"],
        type = "zip",
        urls = ["https://files.pythonhosted.org/packages/ac/da/506b45c82484efb896cadb27348cca8a4ba960968428804417e7b6e866cd/poetry-{}-py3-none-any.whl".format(_POETRY_VERSION)],
    )
