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

""

load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//:version.bzl", "MINIMUM_BAZEL_VERSION")

_RULE_DEPS = [
    # START: maintained by 'bazel run //tools/private:update_pip_deps'
    (
        "pypi__build",
        "https://files.pythonhosted.org/packages/58/91/17b00d5fac63d3dca605f1b8269ba3c65e98059e1fd99d00283e42a454f0/build-0.10.0-py3-none-any.whl",
        "af266720050a66c893a6096a2f410989eeac74ff9a68ba194b3f6473e8e26171",
    ),
    (
        "pypi__click",
        "https://files.pythonhosted.org/packages/00/2e/d53fa4befbf2cfa713304affc7ca780ce4fc1fd8710527771b58311a3229/click-8.1.7-py3-none-any.whl",
        "ae74fb96c20a0277a1d615f1e4d73c8414f5a98db8b799a7931d1582f3390c28",
    ),
    (
        "pypi__colorama",
        "https://files.pythonhosted.org/packages/d1/d6/3965ed04c63042e047cb6a3e6ed1a63a35087b6a609aa3a15ed8ac56c221/colorama-0.4.6-py2.py3-none-any.whl",
        "4f1d9991f5acc0ca119f9d443620b77f9d6b33703e51011c16baf57afb285fc6",
    ),
    (
        "pypi__importlib_metadata",
        "https://files.pythonhosted.org/packages/cc/37/db7ba97e676af155f5fcb1a35466f446eadc9104e25b83366e8088c9c926/importlib_metadata-6.8.0-py3-none-any.whl",
        "3ebb78df84a805d7698245025b975d9d67053cd94c79245ba4b3eb694abe68bb",
    ),
    (
        "pypi__installer",
        "https://files.pythonhosted.org/packages/e5/ca/1172b6638d52f2d6caa2dd262ec4c811ba59eee96d54a7701930726bce18/installer-0.7.0-py3-none-any.whl",
        "05d1933f0a5ba7d8d6296bb6d5018e7c94fa473ceb10cf198a92ccea19c27b53",
    ),
    (
        "pypi__more_itertools",
        "https://files.pythonhosted.org/packages/5a/cb/6dce742ea14e47d6f565589e859ad225f2a5de576d7696e0623b784e226b/more_itertools-10.1.0-py3-none-any.whl",
        "64e0735fcfdc6f3464ea133afe8ea4483b1c5fe3a3d69852e6503b43a0b222e6",
    ),
    (
        "pypi__packaging",
        "https://files.pythonhosted.org/packages/ab/c3/57f0601a2d4fe15de7a553c00adbc901425661bf048f2a22dfc500caf121/packaging-23.1-py3-none-any.whl",
        "994793af429502c4ea2ebf6bf664629d07c1a9fe974af92966e4b8d2df7edc61",
    ),
    (
        "pypi__pep517",
        "https://files.pythonhosted.org/packages/ee/2f/ef63e64e9429111e73d3d6cbee80591672d16f2725e648ebc52096f3d323/pep517-0.13.0-py3-none-any.whl",
        "4ba4446d80aed5b5eac6509ade100bff3e7943a8489de249654a5ae9b33ee35b",
    ),
    (
        "pypi__pip",
        "https://files.pythonhosted.org/packages/50/c2/e06851e8cc28dcad7c155f4753da8833ac06a5c704c109313b8d5a62968a/pip-23.2.1-py3-none-any.whl",
        "7ccf472345f20d35bdc9d1841ff5f313260c2c33fe417f48c30ac46cccabf5be",
    ),
    (
        "pypi__pip_tools",
        "https://files.pythonhosted.org/packages/e8/df/47e6267c6b5cdae867adbdd84b437393e6202ce4322de0a5e0b92960e1d6/pip_tools-7.3.0-py3-none-any.whl",
        "8717693288720a8c6ebd07149c93ab0be1fced0b5191df9e9decd3263e20d85e",
    ),
    (
        "pypi__pyproject_hooks",
        "https://files.pythonhosted.org/packages/d5/ea/9ae603de7fbb3df820b23a70f6aff92bf8c7770043254ad8d2dc9d6bcba4/pyproject_hooks-1.0.0-py3-none-any.whl",
        "283c11acd6b928d2f6a7c73fa0d01cb2bdc5f07c57a2eeb6e83d5e56b97976f8",
    ),
    (
        "pypi__setuptools",
        "https://files.pythonhosted.org/packages/4f/ab/0bcfebdfc3bfa8554b2b2c97a555569c4c1ebc74ea288741ea8326c51906/setuptools-68.1.2-py3-none-any.whl",
        "3d8083eed2d13afc9426f227b24fd1659489ec107c0e86cec2ffdde5c92e790b",
    ),
    (
        "pypi__tomli",
        "https://files.pythonhosted.org/packages/97/75/10a9ebee3fd790d20926a90a2547f0bf78f371b2f13aa822c759680ca7b9/tomli-2.0.1-py3-none-any.whl",
        "939de3e7a6161af0c887ef91b7d41a53e7c5a1ca976325f429cb46ea9bc30ecc",
    ),
    (
        "pypi__wheel",
        "https://files.pythonhosted.org/packages/b8/8b/31273bf66016be6ad22bb7345c37ff350276cfd46e389a0c2ac5da9d9073/wheel-0.41.2-py3-none-any.whl",
        "75909db2664838d015e3d9139004ee16711748a52c8f336b52882266540215d8",
    ),
    (
        "pypi__zipp",
        "https://files.pythonhosted.org/packages/8c/08/d3006317aefe25ea79d3b76c9650afabaf6d63d1c8443b236e7405447503/zipp-3.16.2-py3-none-any.whl",
        "679e51dd4403591b2d6838a48de3d283f3d188412a9782faadf845f298736ba0",
    ),
    # END: maintained by 'bazel run //tools/private:update_pip_deps'
]

_GENERIC_WHEEL = """\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "lib",
    srcs = glob(["**/*.py"]),
    data = glob(["**/*"], exclude=[
        # These entries include those put into user-installed dependencies by
        # data_exclude in /python/pip_install/tools/bazel.py
        # to avoid non-determinism following pip install's behavior.
        "**/*.py",
        "**/*.pyc",
        "**/*.pyc.*",  # During pyc creation, temp files named *.pyc.NNN are created
        "**/* *",
        "**/*.dist-info/RECORD",
        "BUILD",
        "WORKSPACE",
    ]),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
)
"""

# Collate all the repository names so they can be easily consumed
all_requirements = [name for (name, _, _) in _RULE_DEPS]

def requirement(pkg):
    return Label("@pypi__" + pkg + "//:lib")

def pip_install_dependencies():
    """
    Fetch dependencies these rules depend on. Workspaces that use the pip_install rule can call this.

    (However we call it from pip_install, making it optional for users to do so.)
    """

    # We only support Bazel LTS and rolling releases.
    # Give the user an obvious error to upgrade rather than some obscure missing symbol later.
    # It's not guaranteed that users call this function, but it's used by all the pip fetch
    # repository rules so it's likely that most users get the right error.
    versions.check(MINIMUM_BAZEL_VERSION)

    for (name, url, sha256) in _RULE_DEPS:
        maybe(
            http_archive,
            name,
            url = url,
            sha256 = sha256,
            type = "zip",
            build_file_content = _GENERIC_WHEEL,
        )
