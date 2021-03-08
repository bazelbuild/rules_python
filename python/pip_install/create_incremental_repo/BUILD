load("//python/pip_install:repositories.bzl", "requirement")

py_library(
    name = "lib",
    srcs = ["__init__.py"],
    deps = [requirement("pip")]
)

py_test(
    name = "test_create_incremental_repo",
    size = "small",
    srcs = [
        "test_create_incremental_repo.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
        "//python/pip_install/extract_wheels/lib"
    ],
)
