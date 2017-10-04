# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
workspace(name = "io_bazel_rules_python")

# Skydoc stuff
git_repository(
    name = "io_bazel_rules_sass",
    remote = "https://github.com/bazelbuild/rules_sass.git",
    tag = "0.0.3",
)

load("@io_bazel_rules_sass//sass:sass.bzl", "sass_repositories")

sass_repositories()

git_repository(
    name = "io_bazel_skydoc",
    remote = "https://github.com/bazelbuild/skydoc.git",
    commit = "e9be81cf5be41e4200749f5d8aa2db7955f8aacc",
)

load("@io_bazel_skydoc//skylark:skylark.bzl", "skydoc_repositories")

skydoc_repositories()

# Requirements for building our piptool.
load("//python:pip.bzl", "pip_import")

pip_import(
    name = "piptool_deps",
    requirements = "//python:requirements.txt",
)

load(
    "@piptool_deps//:requirements.bzl",
    _piptool_install = "pip_install",
)

_piptool_install()

git_repository(
    name = "subpar",
    remote = "https://github.com/google/subpar",
    tag = "1.0.0",
)

# Test data for WHL tool testing.
http_file(
    name = "grpc_whl",
    sha256 = "c232d6d168cb582e5eba8e1c0da8d64b54b041dd5ea194895a2fe76050916561",
    # From https://pypi.python.org/pypi/grpcio/1.6.0
    url = ("https://pypi.python.org/packages/c6/28/" +
           "67651b4eabe616b27472c5518f9b2aa3f63beab8f62100b26f05ac428639/" +
           "grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl"),
)

http_file(
    name = "futures_whl",
    sha256 = "c4884a65654a7c45435063e14ae85280eb1f111d94e542396717ba9828c4337f",
    # From https://pypi.python.org/pypi/futures
    url = ("https://pypi.python.org/packages/a6/1c/" +
           "72a18c8c7502ee1b38a604a5c5243aa8c2a64f4bba4e6631b1b8972235dd/" +
           "futures-3.1.1-py2-none-any.whl"),
)

http_file(
    name = "mock_whl",
    sha256 = "5ce3c71c5545b472da17b72268978914d0252980348636840bd34a00b5cc96c1",
    # From https://pypi.python.org/pypi/mock
    url = ("https://pypi.python.org/packages/e6/35/" +
           "f187bdf23be87092bd0f1200d43d23076cee4d0dec109f195173fd3ebc79/" +
           "mock-2.0.0-py2.py3-none-any.whl"),
)

# Imports for examples
pip_import(
    name = "examples_helloworld",
    requirements = "//examples/helloworld:requirements.txt",
)

load(
    "@examples_helloworld//:requirements.bzl",
    _helloworld_install = "pip_install",
)

_helloworld_install()

pip_import(
    name = "examples_version",
    requirements = "//examples/version:requirements.txt",
)

load(
    "@examples_version//:requirements.bzl",
    _version_install = "pip_install",
)

_version_install()

pip_import(
    name = "examples_boto",
    requirements = "//examples/boto:requirements.txt",
)

load(
    "@examples_boto//:requirements.bzl",
    _boto_install = "pip_install",
)

_boto_install()
