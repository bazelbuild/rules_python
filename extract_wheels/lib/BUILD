load("//:repositories.bzl", "requirement")

py_library(
    name = "lib",
    visibility = ["//extract_wheels:__subpackages__"],
    srcs = [
        "bazel.py",
        "namespace_pkgs.py",
        "purelib.py",
        "wheel.py",
    ],
    deps = [
        requirement("pkginfo"),
        requirement("setuptools"),
    ],
)

py_test(
    name = "namespace_pkgs_test",
    size = "small",
    srcs = [
        "namespace_pkgs_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)
