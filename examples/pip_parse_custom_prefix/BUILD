load("@rules_python//python:defs.bzl", "py_binary", "py_test")

py_binary(
    name = "main",
    srcs = ["main.py"],
    deps = [
        "@pypi_requests//:pkg",
    ],
)

py_test(
    name = "test",
    srcs = ["test.py"],
    deps = [":main"],
)
