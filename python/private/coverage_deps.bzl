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

"""Dependencies for coverage.py used by the hermetic toolchain.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//python/private:version_label.bzl", "version_label")

# START: maintained by 'bazel run //tools/private/update_deps:update_coverage_deps <version>'
_coverage_deps = {
    "cp310": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/a3/36/b5ae380c05f58544a40ff36f87fa1d6e45f5c2f299335586aac140c341ce/coverage-7.4.3-cp310-cp310-macosx_11_0_arm64.whl",
            "718187eeb9849fc6cc23e0d9b092bc2348821c5e1a901c9f8975df0bc785bfd4",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/9e/48/5ae1ccf4601500af0ca36eba0a2c1f1796e58fb7495de6da55ed43e13e5f/coverage-7.4.3-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "767b35c3a246bcb55b8044fd3a43b8cd553dd1f9f2c1eeb87a302b1f8daa0524",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/50/5a/d727fcd2e0fc3aba61591b6f0fe1e87865ea9b6275f58f35810d6f85b05b/coverage-7.4.3-cp310-cp310-macosx_10_9_x86_64.whl",
            "8580b827d4746d47294c0e0b92854c85a92c2227927433998f0d3320ae8a71b6",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/23/0a/ab5b0f6d6b24f7156624e7697ec7ab49f9d5cdac922da90d9927ae5de1cf/coverage-7.4.3-cp310-cp310-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "ba3a8aaed13770e970b3df46980cb068d1c24af1a1968b7818b69af8c4347efb",
        ),
    },
    "cp311": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/f8/a1/161102d2e26fde2d878d68cc1ed303758dc7b01ee14cc6aa70f5fd1b910d/coverage-7.4.3-cp311-cp311-macosx_11_0_arm64.whl",
            "489763b2d037b164846ebac0cbd368b8a4ca56385c4090807ff9fad817de4113",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/a7/af/1510df1132a68ca876013c0417ca46836252e43871d2623b489e4339c980/coverage-7.4.3-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "451f433ad901b3bb00184d83fd83d135fb682d780b38af7944c9faeecb1e0bfe",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/ca/77/f17a5b199e8ca0443ace312f7e07ff3e4e7ba7d7c52847567d6f1edb22a7/coverage-7.4.3-cp311-cp311-macosx_10_9_x86_64.whl",
            "cbbe5e739d45a52f3200a771c6d2c7acf89eb2524890a4a3aa1a7fa0695d2a47",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/a9/1a/e2120233177b3e2ea9dcfd49a050748060166c74792b2b1db4a803307da4/coverage-7.4.3-cp311-cp311-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "b3ec74cfef2d985e145baae90d9b1b32f85e1741b04cd967aaf9cfa84c1334f3",
        ),
    },
    "cp312": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/9d/d8/111ec1a65fef57ad2e31445af627d481f660d4a9218ee5c774b45187812a/coverage-7.4.3-cp312-cp312-macosx_11_0_arm64.whl",
            "d6cdecaedea1ea9e033d8adf6a0ab11107b49571bbb9737175444cea6eb72328",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/8f/eb/28416f1721a3b7fa28ea499e8a6f867e28146ea2453839c2bca04a001eeb/coverage-7.4.3-cp312-cp312-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "3b2eccb883368f9e972e216c7b4c7c06cabda925b5f06dde0650281cb7666a30",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/11/5c/2cf3e794fa5d1eb443aa8544e2ba3837d75073eaf25a1fda64d232065609/coverage-7.4.3-cp312-cp312-macosx_10_9_x86_64.whl",
            "b51bfc348925e92a9bd9b2e48dad13431b57011fd1038f08316e6bf1df107d10",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/2f/db/70900f10b85a66f761a3a28950ccd07757d51548b1d10157adc4b9415f15/coverage-7.4.3-cp312-cp312-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "b9a4a8dd3dcf4cbd3165737358e4d7dfbd9d59902ad11e3b15eebb6393b0446e",
        ),
    },
    "cp38": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/96/71/1c299b12e80d231e04a2bfd695e761fb779af7ab66f8bd3cb15649be82b3/coverage-7.4.3-cp38-cp38-macosx_11_0_arm64.whl",
            "280459f0a03cecbe8800786cdc23067a8fc64c0bd51dc614008d9c36e1659d7e",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/c7/a7/b00eaa53d904193478eae01625d784b2af8b522a98028f47c831dcc95663/coverage-7.4.3-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "6c0cdedd3500e0511eac1517bf560149764b7d8e65cb800d8bf1c63ebf39edd2",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/e2/bc/f54b24b476db0069ac04ff2cdeb28cd890654c8619761bf818726022c76a/coverage-7.4.3-cp38-cp38-macosx_10_9_x86_64.whl",
            "28ca2098939eabab044ad68850aac8f8db6bf0b29bc7f2887d05889b17346454",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/d0/3a/e882caceca2c7d65791a4a759764a1bf803bbbd10caf38ec41d73a45219e/coverage-7.4.3-cp38-cp38-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "dec9de46a33cf2dd87a5254af095a409ea3bf952d85ad339751e7de6d962cde6",
        ),
    },
    "cp39": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/66/f2/57f5d3c9d2e78c088e4c8dbc933b85fa81c424f23641f10c1aa64052ee4f/coverage-7.4.3-cp39-cp39-macosx_11_0_arm64.whl",
            "77fbfc5720cceac9c200054b9fab50cb2a7d79660609200ab83f5db96162d20c",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/ad/3f/cde6fd2e4cc447bd24e3dc2e79abd2e0fba67ac162996253d3505f8efef4/coverage-7.4.3-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "6679060424faa9c11808598504c3ab472de4531c571ab2befa32f4971835788e",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/d6/cf/4094ac6410b680c91c5e55a56f25f4b3a878e2fcbf773c1cecfbdbaaec4f/coverage-7.4.3-cp39-cp39-macosx_10_9_x86_64.whl",
            "3b253094dbe1b431d3a4ac2f053b6d7ede2664ac559705a704f621742e034f1f",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/b5/ad/effc12b8f72321cb847c5ba7f4ea7ce3e5c19c641f6418131f8fb0ab2f61/coverage-7.4.3-cp39-cp39-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "8640f1fde5e1b8e3439fe482cdc2b0bb6c329f4bb161927c28d2e8879c6029ee",
        ),
    },
}
# END: maintained by 'bazel run //tools/private/update_deps:update_coverage_deps <version>'

_coverage_patch = Label("//python/private:coverage.patch")

def coverage_dep(name, python_version, platform, visibility):
    """Register a single coverage dependency based on the python version and platform.

    Args:
        name: The name of the registered repository.
        python_version: The full python version.
        platform: The platform, which can be found in //python:versions.bzl PLATFORMS dict.
        visibility: The visibility of the coverage tool.

    Returns:
        The label of the coverage tool if the platform is supported, otherwise - None.
    """
    if "windows" in platform:
        # NOTE @aignas 2023-01-19: currently we do not support windows as the
        # upstream coverage wrapper is written in shell. Do not log any warning
        # for now as it is not actionable.
        return None

    abi = "cp" + version_label(python_version)
    url, sha256 = _coverage_deps.get(abi, {}).get(platform, (None, ""))

    if url == None:
        # Some wheels are not present for some builds, so let's silently ignore those.
        return None

    maybe(
        http_archive,
        name = name,
        build_file_content = """
filegroup(
    name = "coverage",
    srcs = ["coverage/__main__.py"],
    data = glob(["coverage/*.py", "coverage/**/*.py", "coverage/*.so"]),
    visibility = {visibility},
)
    """.format(
            visibility = visibility,
        ),
        patch_args = ["-p1"],
        patches = [_coverage_patch],
        sha256 = sha256,
        type = "zip",
        urls = [url],
    )

    return "@{name}//:coverage".format(name = name)
