load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
    name = "extract_wheels",
    srcs = ["__init__.py", "__main__.py"],
    main = "__main__.py",
    deps = ["//extract_wheels/lib"],
)
