licenses(["notice"])

package(default_visibility = ["//visibility:public"])

# export bzl files for the documentation
exports_files(
    glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
)

filegroup(
    name = "distribution",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)
