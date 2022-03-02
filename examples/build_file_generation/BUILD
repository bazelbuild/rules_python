load("@bazel_gazelle//:def.bzl", "gazelle")
load("@pip//:requirements.bzl", "all_whl_requirements")
load("@rules_python//gazelle:def.bzl", "GAZELLE_PYTHON_RUNTIME_DEPS")
load("@rules_python//gazelle/manifest:defs.bzl", "gazelle_python_manifest")
load("@rules_python//gazelle/modules_mapping:def.bzl", "modules_mapping")
load("@rules_python//python:defs.bzl", "py_binary", "py_library")

# This rule fetches the metadata for python packages we depend on. That data is
# required for the gazelle_python_manifest rule to update our manifest file.
modules_mapping(
    name = "modules_map",
    wheels = all_whl_requirements,
)

# Gazelle python extension needs a manifest file mapping from
# an import to the installed package that provides it.
# This macro produces two targets:
# - //:gazelle_python_manifest.update can be used with `bazel run`
#   to recalculate the manifest
# - //:gazelle_python_manifest.test is a test target ensuring that
#   the manifest doesn't need to be updated
gazelle_python_manifest(
    name = "gazelle_python_manifest",
    modules_mapping = ":modules_map",
    pip_repository_incremental = True,
    pip_repository_name = "pip",
    requirements = "//:requirements_lock.txt",
)

# Our gazelle target points to the python gazelle binary.
# This is the simple case where we only need one language supported.
# If you also had proto, go, or other gazelle-supported languages,
# you would also need a gazelle_binary rule.
# See https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.rst#example
gazelle(
    name = "gazelle",
    data = GAZELLE_PYTHON_RUNTIME_DEPS,
    gazelle = "@rules_python//gazelle:gazelle_python_binary",
)

# This rule is auto-generated and managed by Gazelle,
# because it found the __init__.py file in this folder.
py_library(
    name = "build_file_generation",
    srcs = ["__init__.py"],
    visibility = ["//:__subpackages__"],
    deps = ["@pip_requests//:pkg"],
)

py_binary(
    name = "build_file_generation_bin",
    srcs = ["__main__.py"],
    main = "__main__.py",
    visibility = ["//:__subpackages__"],
    deps = [":build_file_generation"],
)
