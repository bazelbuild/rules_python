load("@rules_python//python:defs.bzl", "py_library", "py_test")

py_library(
    name = "random_number_generator",
    srcs = [
        "__init__.py",
        "generate_random_number.py",
    ],
    imports = [".."],
    visibility = ["//:__subpackages__"],
)

py_test(
    name = "random_number_generator_test",
    srcs = ["__test__.py"],
    imports = [".."],
    main = "__test__.py",
    deps = [":random_number_generator"],
)
