# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Dependencies that are needed for rules_python tests and tools."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def rules_python_internal_deps():
    """Fetches all required dependencies for rules_python tests and tools."""

    # This version is also used in python/tests/toolchains/workspace_template/WORKSPACE.tmpl
    # and tests/ignore_root_user_error/WORKSPACE.
    # If you update this dependency, please update the tests as well.
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
            "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/0.7.0/rules_pkg-0.7.0.tar.gz",
            "https://github.com/bazelbuild/rules_pkg/releases/download/0.7.0/rules_pkg-0.7.0.tar.gz",
        ],
        sha256 = "8a298e832762eda1830597d64fe7db58178aa84cd5926d76d5b744d6558941c2",
    )

    maybe(
        http_archive,
        name = "rules_testing",
        sha256 = "8df0a8eb21739ea4b0a03f5dc79e68e245a45c076cfab404b940cc205cb62162",
        strip_prefix = "rules_testing-0.4.0",
        url = "https://github.com/bazelbuild/rules_testing/releases/download/v0.4.0/rules_testing-v0.4.0.tar.gz",
    )

    maybe(
        http_archive,
        name = "rules_license",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_license/releases/download/0.0.7/rules_license-0.0.7.tar.gz",
            "https://github.com/bazelbuild/rules_license/releases/download/0.0.7/rules_license-0.0.7.tar.gz",
        ],
        sha256 = "4531deccb913639c30e5c7512a054d5d875698daeb75d8cf90f284375fe7c360",
    )

    maybe(
        http_archive,
        name = "io_bazel_stardoc",
        url = "https://github.com/bazelbuild/stardoc/archive/6f274e903009158504a9d9130d7f7d5f3e9421ed.tar.gz",
        sha256 = "b5d6891f869d5b5a224316ec4dd9e9d481885a9b1a1c81eb846e20180156f2fa",
        strip_prefix = "stardoc-6f274e903009158504a9d9130d7f7d5f3e9421ed",
    )

    # The below two deps are required for the integration test with bazel
    # gazelle. Maybe the test should be moved to the `gazelle` workspace?
    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "6dc2da7ab4cf5d7bfc7c949776b1b7c733f05e56edc4bcd9022bb249d2e2a996",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.39.1/rules_go-v0.39.1.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.39.1/rules_go-v0.39.1.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "727f3e4edd96ea20c29e8c2ca9e8d2af724d8c7778e7923a854b2c80952bc405",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.30.0/bazel-gazelle-v0.30.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.30.0/bazel-gazelle-v0.30.0.tar.gz",
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

    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "dc3fb206a2cb3441b485eb1e423165b231235a1ea9b031b4433cf7bc1fa460dd",
        strip_prefix = "rules_proto-5.3.0-21.7",
        urls = [
            "https://github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = "75be42bd736f4df6d702a0e4e4d30de9ee40eac024c4b845d17ae4cc831fe4ae",
        strip_prefix = "protobuf-21.7",
        urls = [
            "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/v21.7.tar.gz",
            "https://github.com/protocolbuffers/protobuf/archive/v21.7.tar.gz",
        ],
    )
