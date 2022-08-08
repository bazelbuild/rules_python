load(":pip_install_utils.bzl", "srcs_module")

package(default_visibility = ["//:__subpackages__"])

exports_files([
    "srcs.bzl",
])

filegroup(
    name = "bzl_srcs",
    srcs = glob(["*.bzl"]),
)

srcs_module(
    name = "srcs_module",
    srcs = "//python/pip_install:py_srcs",
    dest = ":srcs.bzl",
)
