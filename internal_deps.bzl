"""Dependencies that are needed for rules_python tests and tools."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def rules_python_internal_deps():
    """Fetches all required dependencies for rules_python tests and tools."""

    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "c6966ec828da198c5d9adbaa94c05e3a1c7f21bd012a0b29ba8ddbccb2c93b0d",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_pkg",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/0.2.4/rules_pkg-0.2.4.tar.gz",
            "https://github.com/bazelbuild/rules_pkg/releases/download/0.2.4/rules_pkg-0.2.4.tar.gz",
        ],
        sha256 = "4ba8f4ab0ff85f2484287ab06c0d871dcb31cc54d439457d28fd4ae14b18450a",
    )

    maybe(
        http_archive,
        name = "io_bazel_stardoc",
        url = "https://github.com/bazelbuild/stardoc/archive/0.4.0.tar.gz",
        sha256 = "6d07d18c15abb0f6d393adbd6075cd661a2219faab56a9517741f0fc755f6f3c",
        strip_prefix = "stardoc-0.4.0",
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "69de5c704a05ff37862f7e0f5534d4f479418afc21806c887db544a316f3cb6b",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.27.0/rules_go-v0.27.0.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.27.0/rules_go-v0.27.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        patch_args = ["-p1"],
        patches = ["@rules_python//gazelle:bazel_gazelle.pr1095.patch"],
        sha256 = "0bb8056ab9ed4cbcab5b74348d8530c0e0b939987b0cfe36c1ab53d35a99e4de",
        strip_prefix = "bazel-gazelle-2834ea44b3ec6371c924baaf28704730ec9d4559",
        urls = [
            # No release since March, and we need subsequent fixes
            "https://github.com/bazelbuild/bazel-gazelle/archive/2834ea44b3ec6371c924baaf28704730ec9d4559.zip",
        ],
    )

    # Test data for WHL tool testing.
    maybe(
        http_file,
        name = "futures_2_2_0_whl",
        downloaded_file_path = "futures-2.2.0-py2.py3-none-any.whl",
        sha256 = "9fd22b354a4c4755ad8c7d161d93f5026aca4cfe999bd2e53168f14765c02cd6",
        # From https://pypi.python.org/pypi/futures/2.2.0
        urls = [
            "https://mirror.bazel.build/pypi.python.org/packages/d7/1d/68874943aa37cf1c483fc61def813188473596043158faa6511c04a038b4/futures-2.2.0-py2.py3-none-any.whl",
            "https://pypi.python.org/packages/d7/1d/68874943aa37cf1c483fc61def813188473596043158faa6511c04a038b4/futures-2.2.0-py2.py3-none-any.whl",
        ],
    )

    maybe(
        http_file,
        name = "futures_3_1_1_whl",
        downloaded_file_path = "futures-3.1.1-py2-none-any.whl",
        sha256 = "c4884a65654a7c45435063e14ae85280eb1f111d94e542396717ba9828c4337f",
        # From https://pypi.python.org/pypi/futures
        urls = [
            "https://mirror.bazel.build/pypi.python.org/packages/a6/1c/72a18c8c7502ee1b38a604a5c5243aa8c2a64f4bba4e6631b1b8972235dd/futures-3.1.1-py2-none-any.whl",
            "https://pypi.python.org/packages/a6/1c/72a18c8c7502ee1b38a604a5c5243aa8c2a64f4bba4e6631b1b8972235dd/futures-3.1.1-py2-none-any.whl",
        ],
    )

    maybe(
        http_file,
        name = "google_cloud_language_whl",
        downloaded_file_path = "google_cloud_language-0.29.0-py2.py3-none-any.whl",
        sha256 = "a2dd34f0a0ebf5705dcbe34bd41199b1d0a55c4597d38ed045bd183361a561e9",
        # From https://pypi.python.org/pypi/google-cloud-language
        urls = [
            "https://mirror.bazel.build/pypi.python.org/packages/6e/86/cae57e4802e72d9e626ee5828ed5a646cf4016b473a4a022f1038dba3460/google_cloud_language-0.29.0-py2.py3-none-any.whl",
            "https://pypi.python.org/packages/6e/86/cae57e4802e72d9e626ee5828ed5a646cf4016b473a4a022f1038dba3460/google_cloud_language-0.29.0-py2.py3-none-any.whl",
        ],
    )

    maybe(
        http_file,
        name = "grpc_whl",
        downloaded_file_path = "grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl",
        sha256 = "c232d6d168cb582e5eba8e1c0da8d64b54b041dd5ea194895a2fe76050916561",
        # From https://pypi.python.org/pypi/grpcio/1.6.0
        urls = [
            "https://mirror.bazel.build/pypi.python.org/packages/c6/28/67651b4eabe616b27472c5518f9b2aa3f63beab8f62100b26f05ac428639/grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl",
            "https://pypi.python.org/packages/c6/28/67651b4eabe616b27472c5518f9b2aa3f63beab8f62100b26f05ac428639/grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl",
        ],
    )

    maybe(
        http_file,
        name = "mock_whl",
        downloaded_file_path = "mock-2.0.0-py2.py3-none-any.whl",
        sha256 = "5ce3c71c5545b472da17b72268978914d0252980348636840bd34a00b5cc96c1",
        # From https://pypi.python.org/pypi/mock
        urls = [
            "https://mirror.bazel.build/pypi.python.org/packages/e6/35/f187bdf23be87092bd0f1200d43d23076cee4d0dec109f195173fd3ebc79/mock-2.0.0-py2.py3-none-any.whl",
            "https://pypi.python.org/packages/e6/35/f187bdf23be87092bd0f1200d43d23076cee4d0dec109f195173fd3ebc79/mock-2.0.0-py2.py3-none-any.whl",
        ],
    )

    maybe(
        http_archive,
        name = "build_bazel_integration_testing",
        urls = [
            "https://github.com/bazelbuild/bazel-integration-testing/archive/165440b2dbda885f8d1ccb8d0f417e6cf8c54f17.zip",
        ],
        strip_prefix = "bazel-integration-testing-165440b2dbda885f8d1ccb8d0f417e6cf8c54f17",
        sha256 = "2401b1369ef44cc42f91dc94443ef491208dbd06da1e1e10b702d8c189f098e3",
    )
