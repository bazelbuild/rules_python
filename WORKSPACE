workspace(name = "rules_python_external")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_python",
    sha256 = "d2865e2ce23ee217aaa408ddaa024ca472114a6f250b46159d27de05530c75e3",
    strip_prefix = "rules_python-7b222cfdb4e59b9fd2a609e1fbb233e94fdcde7c",
    url = "https://github.com/bazelbuild/rules_python/archive/7b222cfdb4e59b9fd2a609e1fbb233e94fdcde7c.tar.gz",
)

load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()

load("//:repositories.bzl", "rules_python_external_dependencies")
rules_python_external_dependencies()

mypy_integration_version = "0.0.7" # latest @ Feb 10th 2020

http_archive(
    name = "mypy_integration",
    sha256 = "bf7ecd386740328f96c343dca095a63b93df7f86f8d3e1e2e6ff46e400880077", # for 0.0.7
    strip_prefix = "bazel-mypy-integration-{version}".format(version = mypy_integration_version),
    url = "https://github.com/thundergolfer/bazel-mypy-integration/archive/{version}.zip".format(
        version = mypy_integration_version
    ),
)

load(
    "@mypy_integration//repositories:repositories.bzl",
    mypy_integration_repositories = "repositories",
)

mypy_integration_repositories()

load("@mypy_integration//:config.bzl", "mypy_configuration")
mypy_configuration("//tools/typing:mypy.ini")

load("@mypy_integration//repositories:deps.bzl", mypy_integration_deps = "deps")
mypy_integration_deps("//tools/typing:mypy_version.txt")

load("@mypy_integration//repositories:pip_repositories.bzl", "pip_deps")
pip_deps()
