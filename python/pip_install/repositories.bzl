""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_RULE_DEPS = [
    (
        "pypi__pip",
        "https://files.pythonhosted.org/packages/54/eb/4a3642e971f404d69d4f6fa3885559d67562801b99d7592487f1ecc4e017/pip-20.3.3-py2.py3-none-any.whl",
        "fab098c8a1758295dd9f57413c199f23571e8fde6cc39c22c78c961b4ac6286d	",
    ),
    (
        "pypi__pkginfo",
        "https://files.pythonhosted.org/packages/4f/3c/535287349af1b117e082f8e77feca52fbe2fdf61ef1e6da6bcc2a72a3a79/pkginfo-1.6.1-py2.py3-none-any.whl",
        "ce14d7296c673dc4c61c759a0b6c14bae34e34eb819c0017bb6ca5b7292c56e9",
    ),
    (
        "pypi__setuptools",
        "https://files.pythonhosted.org/packages/ab/b5/3679d7c98be5b65fa5522671ef437b792d909cf3908ba54fe9eca5d2a766/setuptools-44.1.0-py2.py3-none-any.whl",
        "992728077ca19db6598072414fb83e0a284aca1253aaf2e24bb1e55ee6db1a30",
    ),
    (
        "pypi__wheel",
        "https://files.pythonhosted.org/packages/c9/0b/e0fd299d93cd9331657f415085a4956422959897b333e3791dde40bd711d/wheel-0.36.1-py2.py3-none-any.whl",
        "906864fb722c0ab5f2f9c35b2c65e3af3c009402c108a709c0aca27bc2c9187b",
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
    return "@pypi__" + pkg + "//:lib"

def pip_install_dependencies():
    """
    Fetch dependencies these rules depend on. Workspaces that use the pip_install rule can call this.
    
    (However we call it from pip_install, making it optional for users to do so.)
    """
    for (name, url, sha256) in _RULE_DEPS:
        maybe(
            http_archive,
            name,
            url = url,
            sha256 = sha256,
            type = "zip",
            build_file_content = _GENERIC_WHEEL,
        )
