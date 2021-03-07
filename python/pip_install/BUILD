filegroup(
    name = "distribution",
    srcs = glob(["*.bzl"]) + [
        "BUILD",
        "//python/pip_install/extract_wheels:distribution",
    ],
    visibility = ["//:__pkg__"],
)

exports_files(
    ["pip_repository.bzl", "repositories.bzl"],
    visibility = ["//docs:__pkg__"],
)
