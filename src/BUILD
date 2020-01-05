load("//:repositories.bzl", "all_requirements")

py_library(
    name = "src",
    srcs_version = "PY3",
    srcs = glob(["**/*.py"]),
    data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    deps = ["@"+ repo + "//:lib" for repo in all_requirements],
)

py_test(
    name = "test",
    srcs = glob(["tests/**/*.py"]),
    main = "tests/__main__.py",
    deps = [
        ":src",
    ],
    size="small",
)
