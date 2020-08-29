load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
    name = "extract_wheels",
    srcs = [
        "__init__.py",
        "__main__.py",
    ],
    main = "__main__.py",
    deps = ["//experimental/rules_python_external/extract_wheels/lib"],
)

filegroup(
    name = "distribution",
    srcs = glob(["*"]) + [
        "//experimental/rules_python_external/extract_wheels/lib:distribution",
    ],
    visibility = ["//experimental/rules_python_external:__subpackages__"],
)
