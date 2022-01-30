"""Setup for rules_python tests and tools."""

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@build_bazel_integration_testing//tools:repositories.bzl", "bazel_binaries")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("//:version.bzl", "SUPPORTED_BAZEL_VERSIONS")
load("//gazelle:deps.bzl", _go_repositories = "gazelle_deps")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")

def rules_python_internal_setup():
    """Setup for rules_python tests and tools."""

    # Because we don't use the pip_install rule, we have to call this to fetch its deps
    pip_install_dependencies()

    # Depend on the Bazel binaries for running bazel-in-bazel tests
    bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)

    # gazelle:repository_macro gazelle/deps.bzl%gazelle_deps
    _go_repositories()

    go_rules_dependencies()

    go_register_toolchains(version = "1.17.6")

    gazelle_dependencies()
