py_library(
    name = "src",
    srcs = glob(["*.py"]),
    srcs_version = "PY3",
    deps = [],
)

py_test(
    name = "test",
    srcs = glob(["tests/*.py"]),
    main = "tests/__main__.py",
    deps = [":src"],
)
