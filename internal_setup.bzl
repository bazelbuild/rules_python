"""Setup for rules_python tests and tools."""

load("@build_bazel_integration_testing//tools:repositories.bzl", "bazel_binaries")

# Requirements for building our piptool.
load(
    "@piptool_deps//:requirements.bzl",
    _piptool_install = "pip_install",
)

load("//:version.bzl", "SUPPORTED_BAZEL_VERSIONS")

def rules_python_internal_setup():
    """Setup for rules_python tests and tools."""

    # Requirements for building our piptool.
    _piptool_install()

    # Depend on the Bazel binaries for running bazel-in-bazel tests
    bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)
