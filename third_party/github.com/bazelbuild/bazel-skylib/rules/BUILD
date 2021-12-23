load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

package(default_visibility = ["//visibility:public"])

bzl_library(
    name = "copy_file",
    srcs = ["copy_file.bzl"],
    deps = ["//third_party/github.com/bazelbuild/bazel-skylib/rules/private:copy_file_private"],
)

filegroup(
    name = "test_deps",
    testonly = True,
    srcs = [
        "BUILD",
    ] + glob(["*.bzl"]),
)

# The files needed for distribution
filegroup(
    name = "distribution",
    srcs = [
        "BUILD",
    ] + glob(["*.bzl"]),
    visibility = [
        "//:__pkg__",
    ],
)

# export bzl files for the documentation
exports_files(
    glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
)
