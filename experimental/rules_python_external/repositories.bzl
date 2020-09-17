""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_RULE_DEPS = [
    (
        "pypi__pip",
        "https://files.pythonhosted.org/packages/00/b6/9cfa56b4081ad13874b0c6f96af8ce16cfbc1cb06bedf8e9164ce5551ec1/pip-19.3.1-py2.py3-none-any.whl",
        "6917c65fc3769ecdc61405d3dfd97afdedd75808d200b2838d7d961cebc0c2c7",
    ),
    (
        "pypi__pkginfo",
        "https://files.pythonhosted.org/packages/e6/d5/451b913307b478c49eb29084916639dc53a88489b993530fed0a66bab8b9/pkginfo-1.5.0.1-py2.py3-none-any.whl",
        "a6d9e40ca61ad3ebd0b72fbadd4fba16e4c0e4df0428c041e01e06eb6ee71f32",
    ),
    (
        "pypi__setuptools",
        "https://files.pythonhosted.org/packages/54/28/c45d8b54c1339f9644b87663945e54a8503cfef59cf0f65b3ff5dd17cf64/setuptools-42.0.2-py2.py3-none-any.whl",
        "c8abd0f3574bc23afd2f6fd2c415ba7d9e097c8a99b845473b0d957ba1e2dac6",
    ),
    (
        "pypi__wheel",
        "https://files.pythonhosted.org/packages/00/83/b4a77d044e78ad1a45610eb88f745be2fd2c6d658f9798a15e384b7d57c9/wheel-0.33.6-py2.py3-none-any.whl",
        "f4da1763d3becf2e2cd92a14a7c920f0f00eca30fdde9ea992c836685b9faf28",
    ),
]

_GENERIC_WHEEL = """\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "lib",
    srcs = glob(["**/*.py"]),
    data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
)
"""

# Collate all the repository names so they can be easily consumed
all_requirements = [name for (name, _, _) in _RULE_DEPS]

def requirement(pkg):
    return "@pypi__"+ pkg + "//:lib"

def rules_python_external_dependencies():
    """
    Fetch dependencies these rules depend on. Workspaces that use the rules_python_external should call this.
    """
    for (name, url, sha256) in _RULE_DEPS:
        maybe(
            http_archive,
            name,
            url=url,
            sha256=sha256,
            type="zip",
            build_file_content=_GENERIC_WHEEL,
        )
