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

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

################################
# Skydoc and its dependencies. #
################################

# Skydoc's sass dependency is not covered by skydoc_repositories(), so we have
# to redeclare it here. Watch that the version matches when updating Skydoc's
# version.

git_repository(
    name = "io_bazel_rules_sass",
    # Same commit as Skydoc uses in its own WORKSPACE.
    commit = "8ccf4f1c351928b55d5dddf3672e3667f6978d60",  # 2018-11-23
    remote = "https://github.com/bazelbuild/rules_sass.git",
)

load("@io_bazel_rules_sass//:package.bzl", "rules_sass_dependencies")

rules_sass_dependencies()

# Node is used by sass. This weird (anti-?)pattern of initializing a repo we
# didn't directly import is taken from Skydoc's WORKSPACE.
load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

node_repositories()

load("@io_bazel_rules_sass//:defs.bzl", "sass_repositories")

sass_repositories()

# We implicitly depend on Skydoc importing Skylib under `@bazel_skylib`.
# We don't redeclare it here in order to avoid repeating a definition that
# could get out of sync with Skydoc.

git_repository(
    name = "io_bazel_skydoc",
    commit = "1cdb612e31448c2f6eb25b8aa67d406152275482",  # 2018-11-27
    remote = "https://github.com/bazelbuild/skydoc.git",
)

load("@io_bazel_skydoc//skylark:skylark.bzl", "skydoc_repositories")

skydoc_repositories()

##########################################
# Requirements for building our piptool. #
##########################################

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
    tag = "2.0.0",
)

###################################
# Test data for WHL tool testing. #
###################################

http_file(
    name = "grpc_whl",
    downloaded_file_path = "grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl",
    sha256 = "c232d6d168cb582e5eba8e1c0da8d64b54b041dd5ea194895a2fe76050916561",
    # From https://pypi.python.org/pypi/grpcio/1.6.0
    urls = [("https://pypi.python.org/packages/c6/28/" +
             "67651b4eabe616b27472c5518f9b2aa3f63beab8f62100b26f05ac428639/" +
             "grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl")],
)

http_file(
    name = "futures_3_1_1_whl",
    downloaded_file_path = "futures-3.1.1-py2-none-any.whl",
    sha256 = "c4884a65654a7c45435063e14ae85280eb1f111d94e542396717ba9828c4337f",
    # From https://pypi.python.org/pypi/futures
    urls = [("https://pypi.python.org/packages/a6/1c/" +
             "72a18c8c7502ee1b38a604a5c5243aa8c2a64f4bba4e6631b1b8972235dd/" +
             "futures-3.1.1-py2-none-any.whl")],
)

http_file(
    name = "futures_2_2_0_whl",
    downloaded_file_path = "futures-2.2.0-py2.py3-none-any.whl",
    sha256 = "9fd22b354a4c4755ad8c7d161d93f5026aca4cfe999bd2e53168f14765c02cd6",
    # From https://pypi.python.org/pypi/futures/2.2.0
    urls = [("https://pypi.python.org/packages/d7/1d/" +
             "68874943aa37cf1c483fc61def813188473596043158faa6511c04a038b4/" +
             "futures-2.2.0-py2.py3-none-any.whl")],
)

http_file(
    name = "mock_whl",
    downloaded_file_path = "mock-2.0.0-py2.py3-none-any.whl",
    sha256 = "5ce3c71c5545b472da17b72268978914d0252980348636840bd34a00b5cc96c1",
    # From https://pypi.python.org/pypi/mock
    urls = [("https://pypi.python.org/packages/e6/35/" +
             "f187bdf23be87092bd0f1200d43d23076cee4d0dec109f195173fd3ebc79/" +
             "mock-2.0.0-py2.py3-none-any.whl")],
)

http_file(
    name = "google_cloud_language_whl",
    downloaded_file_path = "google_cloud_language-0.29.0-py2.py3-none-any.whl",
    sha256 = "a2dd34f0a0ebf5705dcbe34bd41199b1d0a55c4597d38ed045bd183361a561e9",
    # From https://pypi.python.org/pypi/google-cloud-language
    urls = [("https://pypi.python.org/packages/6e/86/" +
             "cae57e4802e72d9e626ee5828ed5a646cf4016b473a4a022f1038dba3460/" +
             "google_cloud_language-0.29.0-py2.py3-none-any.whl")],
)

#########################
# Imports for examples. #
#########################

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

pip_import(
    name = "examples_extras",
    requirements = "//examples/extras:requirements.txt",
)

load(
    "@examples_extras//:requirements.bzl",
    _extras_install = "pip_install",
)

_extras_install()
