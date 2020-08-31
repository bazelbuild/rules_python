load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("//experimental/rules_python_external:repositories.bzl", "requirement")

py_library(
    name = "lib",
    srcs = [
        "bazel.py",
        "namespace_pkgs.py",
        "purelib.py",
        "requirements.py",
        "wheel.py",
    ],
    visibility = ["//experimental/rules_python_external/extract_wheels:__subpackages__"],
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

py_test(
    name = "requirements_test",
    size = "small",
    srcs = [
        "requirements_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)

filegroup(
    name = "distribution",
    srcs = glob(
        ["*"],
        exclude = ["*_test.py"],
    ),
    visibility = ["//experimental/rules_python_external:__subpackages__"],
)
