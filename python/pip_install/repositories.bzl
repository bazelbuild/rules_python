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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_RULE_DEPS = [
    # START: maintained by 'bazel run //tools/private/update_deps:update_pip_deps'
    (
        "pypi__build",
        "https://files.pythonhosted.org/packages/93/dd/b464b728b866aaa62785a609e0dd8c72201d62c5f7c53e7c20f4dceb085f/build-1.0.3-py3-none-any.whl",
        "589bf99a67df7c9cf07ec0ac0e5e2ea5d4b37ac63301c4986d1acb126aa83f8f",
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
        "https://files.pythonhosted.org/packages/ec/1a/610693ac4ee14fcdf2d9bf3c493370e4f2ef7ae2e19217d7a237ff42367d/packaging-23.2-py3-none-any.whl",
        "8c491190033a9af7e1d931d0b5dacc2ef47509b34dd0de67ed209b5203fc88c7",
    ),
    (
        "pypi__pep517",
        "https://files.pythonhosted.org/packages/ee/2f/ef63e64e9429111e73d3d6cbee80591672d16f2725e648ebc52096f3d323/pep517-0.13.0-py3-none-any.whl",
        "4ba4446d80aed5b5eac6509ade100bff3e7943a8489de249654a5ae9b33ee35b",
    ),
    (
        "pypi__pip",
        "https://files.pythonhosted.org/packages/47/6a/453160888fab7c6a432a6e25f8afe6256d0d9f2cbd25971021da6491d899/pip-23.3.1-py3-none-any.whl",
        "55eb67bb6171d37447e82213be585b75fe2b12b359e993773aca4de9247a052b",
    ),
    (
        "pypi__pip_tools",
        "https://files.pythonhosted.org/packages/e8/df/47e6267c6b5cdae867adbdd84b437393e6202ce4322de0a5e0b92960e1d6/pip_tools-7.3.0-py3-none-any.whl",
        "8717693288720a8c6ebd07149c93ab0be1fced0b5191df9e9decd3263e20d85e",
    ),
    (
        "pypi__pypiserver",
        "https://files.pythonhosted.org/packages/34/95/6c70e2f7e8375354fd7b1db08405c93674f2e4ce4e714f379fadd06a92b1/pypiserver-2.0.1-py2.py3-none-any.whl",
        "1dd98fb99d2da4199fb44c7284e57d69a9f7fda2c6c8dc01975c151c592677bf",
    ),
    (
        "pypi__pyproject_hooks",
        "https://files.pythonhosted.org/packages/d5/ea/9ae603de7fbb3df820b23a70f6aff92bf8c7770043254ad8d2dc9d6bcba4/pyproject_hooks-1.0.0-py3-none-any.whl",
        "283c11acd6b928d2f6a7c73fa0d01cb2bdc5f07c57a2eeb6e83d5e56b97976f8",
    ),
    (
        "pypi__setuptools",
        "https://files.pythonhosted.org/packages/bb/26/7945080113158354380a12ce26873dd6c1ebd88d47f5bc24e2c5bb38c16a/setuptools-68.2.2-py3-none-any.whl",
        "b454a35605876da60632df1a60f736524eb73cc47bbc9f3f1ef1b644de74fd2a",
    ),
    (
        "pypi__tomli",
        "https://files.pythonhosted.org/packages/97/75/10a9ebee3fd790d20926a90a2547f0bf78f371b2f13aa822c759680ca7b9/tomli-2.0.1-py3-none-any.whl",
        "939de3e7a6161af0c887ef91b7d41a53e7c5a1ca976325f429cb46ea9bc30ecc",
    ),
    (
        "pypi__wheel",
        "https://files.pythonhosted.org/packages/fa/7f/4c07234086edbce4a0a446209dc0cb08a19bb206a3ea53b2f56a403f983b/wheel-0.41.3-py3-none-any.whl",
        "488609bc63a29322326e05560731bf7bfea8e48ad646e1f5e40d366607de0942",
    ),
    (
        "pypi__zipp",
        "https://files.pythonhosted.org/packages/d9/66/48866fc6b158c81cc2bfecc04c480f105c6040e8b077bc54c634b4a67926/zipp-3.17.0-py3-none-any.whl",
        "0e923e726174922dce09c53c59ad483ff7bbb8e572e00c7f7c46b88556409f31",
    ),
    # END: maintained by 'bazel run //tools/private/update_deps:update_pip_deps'
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
    Fetch dependencies these rules depend on. Workspaces that use the pip_parse rule can call this.
    """
    for (name, url, sha256) in _RULE_DEPS:
        maybe(
            http_archive,
            name,
            url = url,
            sha256 = sha256,
            type = "zip",
            build_file_content = _GENERIC_WHEEL,
        )
