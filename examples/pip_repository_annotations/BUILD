load("@pip_installed//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_test")
load("@rules_python//python:pip.bzl", "compile_pip_requirements")

exports_files(
    glob(["data/**"]),
    visibility = ["//visibility:public"],
)

# This rule adds a convenient way to update the requirements file.
compile_pip_requirements(
    name = "requirements",
    extra_args = ["--allow-unsafe"],
)

py_test(
    name = "pip_parse_annotations_test",
    srcs = ["pip_repository_annotations_test.py"],
    env = {"WHEEL_PKG_DIR": "pip_parsed_wheel"},
    main = "pip_repository_annotations_test.py",
    deps = [
        "@pip_parsed_wheel//:pkg",
        "@rules_python//python/runfiles",
    ],
)

py_test(
    name = "pip_install_annotations_test",
    srcs = ["pip_repository_annotations_test.py"],
    env = {"WHEEL_PKG_DIR": "pip_installed/pypi__wheel"},
    main = "pip_repository_annotations_test.py",
    deps = [
        requirement("wheel"),
        "@rules_python//python/runfiles",
    ],
)
