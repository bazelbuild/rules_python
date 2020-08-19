load("//:repositories.bzl", "all_requirements")

py_binary(
    name = "extract_wheels",
    srcs = ["__init__.py", "__main__.py"],
    main = "__main__.py",
    deps = ["//extract_wheels/lib"],
)
