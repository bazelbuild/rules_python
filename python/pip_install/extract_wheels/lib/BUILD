load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")
load(":annotations_test_helpers.bzl", "package_annotation", "package_annotations_file")

py_library(
    name = "lib",
    srcs = [
        "annotation.py",
        "arguments.py",
        "bazel.py",
        "namespace_pkgs.py",
        "purelib.py",
        "requirements.py",
        "wheel.py",
    ],
    visibility = [
        "//python/pip_install/extract_wheels:__subpackages__",
        "//python/pip_install/parse_requirements_to_bzl:__subpackages__",
    ],
    deps = [
        requirement("pkginfo"),
        requirement("setuptools"),
    ],
)

package_annotations_file(
    name = "mock_annotations",
    annotations = {
        "pkg_a": package_annotation(),
        "pkg_b": package_annotation(
            data_exclude_glob = [
                "*.foo",
                "*.bar",
            ],
        ),
        "pkg_c": package_annotation(
            additive_build_content = """\
cc_library(
    name = "my_target",
    hdrs = glob(["**/*.h"]),
    srcs = glob(["**/*.cc"]),
)
""",
            data = [":my_target"],
        ),
        "pkg_d": package_annotation(
            srcs_exclude_glob = ["pkg_d/tests/**"],
        ),
    },
    tags = ["manual"],
)

py_test(
    name = "annotations_test",
    size = "small",
    srcs = ["annotations_test.py"],
    data = [":mock_annotations"],
    env = {"MOCK_ANNOTATIONS": "$(rootpath :mock_annotations)"},
    tags = ["unit"],
    deps = [":lib"],
)

py_test(
    name = "bazel_test",
    size = "small",
    srcs = [
        "bazel_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)

py_test(
    name = "namespace_pkgs_test",
    size = "small",
    srcs = [
        "namespace_pkgs_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)

py_test(
    name = "requirements_test",
    size = "small",
    srcs = [
        "requirements_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
)

py_test(
    name = "arguments_test",
    size = "small",
    srcs = [
        "arguments_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
        "//python/pip_install/parse_requirements_to_bzl:lib",
    ],
)

py_test(
    name = "whl_filegroup_test",
    size = "small",
    srcs = ["whl_filegroup_test.py"],
    data = ["//examples/wheel:minimal_with_py_package"],
    main = "whl_filegroup_test.py",
    tags = ["unit"],
    deps = [":lib"],
)

py_test(
    name = "requirements_bzl_test",
    size = "small",
    srcs = [
        "requirements_bzl_test.py",
    ],
    deps = [
        ":lib",
    ],
)

py_test(
    name = "purelib_test",
    size = "small",
    srcs = [
        "purelib_test.py",
    ],
    deps = [
        ":lib",
    ],
)

filegroup(
    name = "distribution",
    srcs = glob(
        ["*"],
        exclude = ["*_test.py"],
    ),
    visibility = ["//python/pip_install:__subpackages__"],
)

filegroup(
    name = "py_srcs",
    srcs = glob(
        include = ["**/*.py"],
        exclude = ["**/*_test.py"],
    ),
    visibility = ["//python/pip_install:__subpackages__"],
)
