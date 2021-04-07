load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")

py_library(
    name = "lib",
    srcs = [
        "arguments.py",
        "bazel.py",
        "namespace_pkgs.py",
        "purelib.py",
        "requirements.py",
        "wheel.py",
    ],
    visibility = [
        "//python/pip_install/extract_wheels:__subpackages__",
        "//python/pip_install/parse_requirements_to_bzl:__subpackages__",
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

py_test(
    name = "arguments_test",
    size = "small",
    srcs = [
        "arguments_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
        "//python/pip_install/parse_requirements_to_bzl:lib",
    ],
)

py_test(
    name = "whl_filegroup_test",
    size = "small",
    srcs = [
        "whl_filegroup_test.py",
    ],
    data = ["//examples/wheel:minimal_with_py_package"],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)

py_test(
    name = "requirements_bzl_test",
    size = "small",
    srcs = [
        "requirements_bzl_test.py",
    ],
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
    visibility = ["//python/pip_install:__subpackages__"],
)
