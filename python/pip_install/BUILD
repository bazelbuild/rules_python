load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

filegroup(
    name = "distribution",
    srcs = glob(["*.bzl"]) + [
        "BUILD",
        "//python/pip_install/extract_wheels:distribution",
        "//python/pip_install/parse_requirements_to_bzl:distribution",
    ],
    visibility = ["//:__pkg__"],
)

bzl_library(
    name = "bzl",
    srcs = [
        "pip_repository.bzl",
        "repositories.bzl",
    ],
    visibility = ["//docs:__pkg__"],
)
