"""Dependencies for coverage.py used by the hermetic toolchain.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# Update with './tools/update_coverage_deps.py <version>'
#START: managed by update_coverage_deps.py script
_coverage_deps = []
#END: managed by update_coverage_deps.py script

def install_coverage_deps():
    """Register the dependency for the coverage dep.
    """
    for name, url, sha256 in _coverage_deps:
        maybe(
            http_archive,
            name = name,
            build_file_content = """
py_library(
    name = "coverage",
    srcs = ["coverage/__main__.py"],
    data = glob(["coverage/*", "coverage/**/*.py", "coverage/*.so"]),
    visibility = ["//visibility:public"],
)
        """,
            sha256 = sha256,
            type = "zip",
            urls = [url],
        )
