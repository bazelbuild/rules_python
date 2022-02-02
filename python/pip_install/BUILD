exports_files(["pip_compile.py"])

filegroup(
    name = "distribution",
    srcs = glob(["*.bzl"]) + [
        "BUILD",
        "pip_compile.py",
        "//python/pip_install/extract_wheels:distribution",
        "//python/pip_install/parse_requirements_to_bzl:distribution",
        "//python/pip_install/private:distribution",
    ],
    visibility = ["//:__pkg__"],
)

filegroup(
    name = "bzl",
    srcs = glob(["*.bzl"]) + [
        "//python/pip_install/private:bzl_srcs",
    ],
    visibility = ["//:__subpackages__"],
)

filegroup(
    name = "py_srcs",
    srcs = [
        "//python/pip_install/extract_wheels:py_srcs",
        "//python/pip_install/parse_requirements_to_bzl:py_srcs",
    ],
    visibility = ["//python/pip_install/private:__pkg__"],
)

exports_files(
    glob(["*.bzl"]),
    visibility = ["//docs:__pkg__"],
)
