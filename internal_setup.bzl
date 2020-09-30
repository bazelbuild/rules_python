"""Setup for rules_python tests and tools."""

load("@build_bazel_integration_testing//tools:repositories.bzl", "bazel_binaries")

# Requirements for building our piptool.
load(
    "@piptool_deps//:requirements.bzl",
    _piptool_install = "pip_install",
)
load("//:version.bzl", "SUPPORTED_BAZEL_VERSIONS")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")

def rules_python_internal_setup():
    """Setup for rules_python tests and tools."""

    # Requirements for building our piptool.
    _piptool_install()

    # Because we don't use the pip_install rule, we have to call this to fetch its deps
    pip_install_dependencies()

    # Depend on the Bazel binaries for running bazel-in-bazel tests
    bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)
