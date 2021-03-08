load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")

py_library(
    name = "lib",
    srcs = [
        "bazel.py",
        "namespace_pkgs.py",
        "purelib.py",
        "requirements.py",
        "wheel.py",
        "utilities.py",
    ],
    visibility = [
        "//python/pip_install/extract_wheels:__subpackages__",
        "//python/pip_install/create_incremental_repo:__pkg__"
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
    name = "utilities_test",
    size = "small",
    srcs = [
        "utilities_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)

py_test(
    name = "whl_filegroup_test",
    size = "small",
    srcs = [
        "whl_filegroup_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
    data = ["//examples/wheel:minimal_with_py_package"]
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
