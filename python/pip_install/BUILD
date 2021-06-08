exports_files(["pip_compile.py"])

filegroup(
    name = "distribution",
    srcs = glob(["*.bzl"]) + [
        "BUILD",
        "pip_compile.py",
        "//python/pip_install/extract_wheels:distribution",
        "//python/pip_install/parse_requirements_to_bzl:distribution",
    ],
    visibility = ["//:__pkg__"],
)

filegroup(
    name = "bzl",
    srcs = [
        "pip_repository.bzl",
        "repositories.bzl",
    ],
    visibility = ["//:__pkg__"],
)

exports_files(
    [
        "pip_repository.bzl",
        "repositories.bzl",
    ],
    visibility = ["//docs:__pkg__"],
)
