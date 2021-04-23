load("@rules_python//python:defs.bzl", "py_binary",
     "py_library", "py_test", "py_test_suite", "pytest_test")
load("@pip//:requirements.bzl", "requirement")

TEST_DEPS = [
    requirement("pluggy"),
    requirement("py"),
    requirement("pytest"),
    requirement("pytest-instafail"),
    requirement("pytest-trio"),
    requirement("pytest-mock"),
]

py_library(
    name="lib",
    srcs="main.py"
)

py_test_suite(
    name="unit",
    size="small",
    srcs="main_tests.py",
    args=[
        "--instafail",
    ],
    deps=[
        ":lib",
    ] + TEST_DEPS,
)


