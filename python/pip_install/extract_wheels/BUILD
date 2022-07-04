load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")
load(":annotations_test_helpers.bzl", "package_annotation", "package_annotations_file")

py_library(
    name = "lib",
    srcs = [
        "annotation.py",
        "arguments.py",
        "bazel.py",
        "extract_single_wheel.py",
        "extract_wheels.py",
        "namespace_pkgs.py",
        "parse_requirements_to_bzl.py",
        "requirements.py",
        "wheel.py",
    ],
    deps = [
        requirement("installer"),
        requirement("setuptools"),
    ],
)

py_binary(
    name = "extract_wheels",
    srcs = [
        "extract_wheels.py",
    ],
    deps = [":lib"],
)

py_binary(
    name = "extract_single_wheel",
    srcs = [
        "extract_single_wheel.py",
    ],
    deps = [":lib"],
)

py_binary(
    name = "parse_requirements_to_bzl",
    srcs = [
        "parse_requirements_to_bzl.py",
    ],
    deps = [":lib"],
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
            # The `join` and `strip` here accounts for potential differences
            # in new lines between unix and windows hosts.
            additive_build_content = "\n".join([line.strip() for line in """\
cc_library(
    name = "my_target",
    hdrs = glob(["**/*.h"]),
    srcs = glob(["**/*.cc"]),
)
""".splitlines()]),
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
    deps = [
        ":lib",
        "//python/runfiles",
    ],
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
    name = "parse_requirements_to_bzl_test",
    size = "small",
    srcs = [
        "parse_requirements_to_bzl_test.py",
    ],
    tags = ["unit"],
    deps = [
        ":lib",
    ],
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
