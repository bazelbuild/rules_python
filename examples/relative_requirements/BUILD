load("@pip//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_test")

py_test(
    name = "main",
    srcs = ["main.py"],
    deps = [
        requirement("relative_package_name"),
    ],
)
