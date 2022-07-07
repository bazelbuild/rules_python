exports_files(
    ["pytest.tmpl.py"],
    visibility = ["//visibility:public"],
)

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "distribution",
    srcs = glob(["**"]),
    visibility = ["//python:__pkg__"],
)

# Filegroup of bzl files that can be used by downstream rules for documentation generation
# Using a filegroup rather than bzl_library to not give a transitive dependency on Skylib
filegroup(
    name = "bzl",
    srcs = glob(["**/*.bzl"]),
    visibility = ["//python:__pkg__"],
)

# Needed to define bzl_library targets for docgen. (We don't define the
# bzl_library target here because it'd give our users a transitive dependency
# on Skylib.)
exports_files(
    [
        "defs.bzl",
    ],
    visibility = ["//docs:__pkg__"],
)
