load("@bazel_federation//:repositories.bzl", "bazel_stardoc", "rules_pkg")
load("@bazel_federation//:third_party_repositories.bzl", "futures_2_whl", "futures_3_whl", "google_cloud_language_whl", "grpc_whl", "mock_whl", "subpar")
load("@rules_python//python:pip.bzl", "pip_import")


def rules_python_internal_deps():
    bazel_stardoc()

    subpar()

    # Test data for WHL tool testing.
    futures_2_whl()
    futures_3_whl()
    google_cloud_language_whl()
    grpc_whl()
    mock_whl()

    piptool()
    examples()

    # For packaging and distribution
    rules_pkg()


def piptool():
    pip_import(
        name = "piptool_deps",
        requirements = "@rules_python//python:requirements.txt",
    )


def examples():
    pip_import(
        name = "examples_helloworld",
        requirements = "@rules_python//examples/helloworld:requirements.txt",
    )
    pip_import(
        name = "examples_version",
        requirements = "@rules_python//examples/version:requirements.txt",
    )
    pip_import(
        name = "examples_boto",
        requirements = "@rules_python//examples/boto:requirements.txt",
    )
    pip_import(
        name = "examples_extras",
        requirements = "@rules_python//examples/extras:requirements.txt",
    )
