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
    # START: maintained by 'bazel run //tools/private:update_pip_deps'
    (
        "pypi__SecretStorage",
        "https://files.pythonhosted.org/packages/54/24/b4293291fa1dd830f353d2cb163295742fa87f179fcc8a20a306a81978b7/SecretStorage-3.3.3-py3-none-any.whl",
        "f356e6628222568e3af06f2eba8df495efa13b3b63081dafd4f7d9a7b7bc9f99",
    ),
    (
        "pypi__build",
        "https://files.pythonhosted.org/packages/4f/81/4849059526d02fcc9708e19346dd740e8b9edd2f0675ea7c38302d6729df/build-1.1.1-py3-none-any.whl",
        "8ed0851ee76e6e38adce47e4bee3b51c771d86c64cf578d0c2245567ee200e73",
    ),
    (
        "pypi__cffi",
        "https://files.pythonhosted.org/packages/9b/89/a31c81e36bbb793581d8bba4406a8aac4ba84b2559301c44eef81f4cf5df/cffi-1.16.0-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "7b78010e7b97fef4bee1e896df8a4bbb6712b7f05b7ef630f9d1da00f6444d2e",
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
        "pypi__cryptography",
        "https://files.pythonhosted.org/packages/48/c8/c0962598c43d3cff2c9d6ac66d0c612bdfb1975be8d87b8889960cf8c81d/cryptography-42.0.5-cp39-abi3-manylinux_2_28_x86_64.whl",
        "cd2030f6650c089aeb304cf093f3244d34745ce0cfcc39f20c6fbfe030102e2a",
    ),
    (
        "pypi__importlib_metadata",
        "https://files.pythonhosted.org/packages/db/62/6879ab53ad4997b627fc67241a41eabf7163299c59580c6ca4aa5ae6b677/importlib_metadata-7.0.2-py3-none-any.whl",
        "f4bc4c0c070c490abf4ce96d715f68e95923320370efb66143df00199bb6c100",
    ),
    (
        "pypi__installer",
        "https://files.pythonhosted.org/packages/e5/ca/1172b6638d52f2d6caa2dd262ec4c811ba59eee96d54a7701930726bce18/installer-0.7.0-py3-none-any.whl",
        "05d1933f0a5ba7d8d6296bb6d5018e7c94fa473ceb10cf198a92ccea19c27b53",
    ),
    (
        "pypi__jaraco_classes",
        "https://files.pythonhosted.org/packages/eb/57/d3590a153d7c1970f466f69fa2570e1a93a34d8f88f23c11411df73729bf/jaraco.classes-3.3.1-py3-none-any.whl",
        "86b534de565381f6b3c1c830d13f931d7be1a75f0081c57dff615578676e2206",
    ),
    (
        "pypi__jeepney",
        "https://files.pythonhosted.org/packages/ae/72/2a1e2290f1ab1e06f71f3d0f1646c9e4634e70e1d37491535e19266e8dc9/jeepney-0.8.0-py3-none-any.whl",
        "c0a454ad016ca575060802ee4d590dd912e35c122fa04e70306de3d076cce755",
    ),
    (
        "pypi__keyring",
        "https://files.pythonhosted.org/packages/7c/23/d557507915181687e4a613e1c8a01583fd6d7cb7590e1f039e357fe3b304/keyring-24.3.1-py3-none-any.whl",
        "df38a4d7419a6a60fea5cef1e45a948a3e8430dd12ad88b0f423c5c143906218",
    ),
    (
        "pypi__more_itertools",
        "https://files.pythonhosted.org/packages/50/e2/8e10e465ee3987bb7c9ab69efb91d867d93959095f4807db102d07995d94/more_itertools-10.2.0-py3-none-any.whl",
        "686b06abe565edfab151cb8fd385a05651e1fdf8f0a14191e4439283421f8684",
    ),
    (
        "pypi__packaging",
        "https://files.pythonhosted.org/packages/49/df/1fceb2f8900f8639e278b056416d49134fb8d84c5942ffaa01ad34782422/packaging-24.0-py3-none-any.whl",
        "2ddfb553fdf02fb784c234c7ba6ccc288296ceabec964ad2eae3777778130bc5",
    ),
    (
        "pypi__pep517",
        "https://files.pythonhosted.org/packages/25/6e/ca4a5434eb0e502210f591b97537d322546e4833dcb4d470a48c375c5540/pep517-0.13.1-py3-none-any.whl",
        "31b206f67165b3536dd577c5c3f1518e8fbaf38cbc57efff8369a392feff1721",
    ),
    (
        "pypi__pip",
        "https://files.pythonhosted.org/packages/8a/6a/19e9fe04fca059ccf770861c7d5721ab4c2aebc539889e97c7977528a53b/pip-24.0-py3-none-any.whl",
        "ba0d021a166865d2265246961bec0152ff124de910c5cc39f1156ce3fa7c69dc",
    ),
    (
        "pypi__pip_tools",
        "https://files.pythonhosted.org/packages/0d/dc/38f4ce065e92c66f058ea7a368a9c5de4e702272b479c0992059f7693941/pip_tools-7.4.1-py3-none-any.whl",
        "4c690e5fbae2f21e87843e89c26191f0d9454f362d8acdbd695716493ec8b3a9",
    ),
    (
        "pypi__pycparser",
        "https://files.pythonhosted.org/packages/62/d5/5f610ebe421e85889f2e55e33b7f9a6795bd982198517d912eb1c76e1a53/pycparser-2.21-py2.py3-none-any.whl",
        "8ee45429555515e1f6b185e78100aea234072576aa43ab53aefcae078162fca9",
    ),
    (
        "pypi__pyproject_hooks",
        "https://files.pythonhosted.org/packages/d5/ea/9ae603de7fbb3df820b23a70f6aff92bf8c7770043254ad8d2dc9d6bcba4/pyproject_hooks-1.0.0-py3-none-any.whl",
        "283c11acd6b928d2f6a7c73fa0d01cb2bdc5f07c57a2eeb6e83d5e56b97976f8",
    ),
    (
        "pypi__setuptools",
        "https://files.pythonhosted.org/packages/c0/7a/3da654f49c95d0cc6e9549a855b5818e66a917e852ec608e77550c8dc08b/setuptools-69.1.1-py3-none-any.whl",
        "02fa291a0471b3a18b2b2481ed902af520c69e8ae0919c13da936542754b4c56",
    ),
    (
        "pypi__tomli",
        "https://files.pythonhosted.org/packages/97/75/10a9ebee3fd790d20926a90a2547f0bf78f371b2f13aa822c759680ca7b9/tomli-2.0.1-py3-none-any.whl",
        "939de3e7a6161af0c887ef91b7d41a53e7c5a1ca976325f429cb46ea9bc30ecc",
    ),
    (
        "pypi__wheel",
        "https://files.pythonhosted.org/packages/c7/c3/55076fc728723ef927521abaa1955213d094933dc36d4a2008d5101e1af5/wheel-0.42.0-py3-none-any.whl",
        "177f9c9b0d45c47873b619f5b650346d632cdc35fb5e4d25058e09c9e581433d",
    ),
    (
        "pypi__zipp",
        "https://files.pythonhosted.org/packages/d9/66/48866fc6b158c81cc2bfecc04c480f105c6040e8b077bc54c634b4a67926/zipp-3.17.0-py3-none-any.whl",
        "0e923e726174922dce09c53c59ad483ff7bbb8e572e00c7f7c46b88556409f31",
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
