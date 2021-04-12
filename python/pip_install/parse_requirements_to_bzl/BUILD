load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")

py_binary(
    name = "parse_requirements_to_bzl",
    srcs = [
        "__init__.py",
        "__main__.py",
    ],
    main = "__main__.py",
    deps = ["//python/pip_install/extract_wheels/lib"],
)

py_library(
    name = "lib",
    srcs = ["__init__.py"],
    visibility = ["//python/pip_install/extract_wheels:__subpackages__"],
    deps = [requirement("pip")],
)

py_test(
    name = "parse_requirements_to_bzl_test",
    size = "small",
    srcs = [
        "parse_requirements_to_bzl_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
        "//python/pip_install/extract_wheels/lib",
    ],
)

filegroup(
    name = "distribution",
    srcs = glob(
        ["*"],
        exclude = ["*_test.py"],
    ) + [
        "//python/pip_install/parse_requirements_to_bzl/extract_single_wheel:distribution",
    ],
    visibility = ["//python/pip_install:__subpackages__"],
)
