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
            "https://files.pythonhosted.org/packages/ed/2d/db83db65d0c3d457f993830b97271a80f11bdc051d86dd44405c436db147/coverage-7.4.1-cp310-cp310-macosx_11_0_arm64.whl",
            "0193657651f5399d433c92f8ae264aff31fc1d066deee4b831549526433f3f61",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/8f/bf/9b1e104690d4976b17d515ee49b648c26d7244e148d1c845708d58b8f4fe/coverage-7.4.1-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "d17bbc946f52ca67adf72a5ee783cd7cd3477f8f8796f59b4974a9b59cacc9ee",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/26/1f/430384b8e428c87950583e775fee97bc83bcfd93a2ecc00b5e55a5a052a5/coverage-7.4.1-cp310-cp310-macosx_10_9_x86_64.whl",
            "077d366e724f24fc02dbfe9d946534357fda71af9764ff99d73c3c596001bbd7",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/49/d5/9d66fd984979b58927588efb0398953acbdb4c45eb7cfcd74fa9b8d51d12/coverage-7.4.1-cp310-cp310-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "6dceb61d40cbfcf45f51e59933c784a50846dc03211054bd76b421a713dcdf19",
        ),
    },
    "cp311": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/12/8d/e078f0ccc4e91aa44f7754f0bac18bd6c62780a029b5d30f6242c6e06b23/coverage-7.4.1-cp311-cp311-macosx_11_0_arm64.whl",
            "3cacfaefe6089d477264001f90f55b7881ba615953414999c46cc9713ff93c8c",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/87/71/0d90c4cda220c1f20f0eeaa997633eb1ec0bcaf5d8250c299d0f27a5885d/coverage-7.4.1-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "5d6850e6e36e332d5511a48a251790ddc545e16e8beaf046c03985c69ccb2676",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/0b/bd/008f9dad615d67e47221a983cd46cb5e87002e569dec60daa84d1b422859/coverage-7.4.1-cp311-cp311-macosx_10_9_x86_64.whl",
            "b8ffb498a83d7e0305968289441914154fb0ef5d8b3157df02a90c6695978295",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/d5/a7/36bd1c439fab5d450c69b7cdf4be4291d56885ae8be11ebed9ec240b919f/coverage-7.4.1-cp311-cp311-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "dfd1e1b9f0898817babf840b77ce9fe655ecbe8b1b327983df485b30df8cc011",
        ),
    },
    "cp312": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/de/37/4f3eb8e6f4be39eeca4318e3c2ef10e954e86871a68b0e71f004835d6a30/coverage-7.4.1-cp312-cp312-macosx_11_0_arm64.whl",
            "23b27b8a698e749b61809fb637eb98ebf0e505710ec46a8aa6f1be7dc0dc43a6",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/10/97/ca7dec2d9a1262bc0dbfb757989444fec8cde908083b15fb3339210aa7b8/coverage-7.4.1-cp312-cp312-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "3e3424c554391dc9ef4a92ad28665756566a28fecf47308f91841f6c49288e66",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/37/34/2089e0b24759a207184b41a4e4b4af7004282a5b3a93bb408c2fa19b9b16/coverage-7.4.1-cp312-cp312-macosx_10_9_x86_64.whl",
            "f68ef3660677e6624c8cace943e4765545f8191313a07288a53d3da188bd8581",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/c3/92/f2d89715c3397e76fe365b1ecbb861d1279ff8d47d23635040a358bc75dc/coverage-7.4.1-cp312-cp312-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "fe558371c1bdf3b8fa03e097c523fb9645b8730399c14fe7721ee9c9e2a545d3",
        ),
    },
    "cp38": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/13/4e/66a3821f6fc8a28d07740d9115fdacffb7e7d61431b9ae112bacde846327/coverage-7.4.1-cp38-cp38-macosx_11_0_arm64.whl",
            "918440dea04521f499721c039863ef95433314b1db00ff826a02580c1f503e45",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/2a/12/89d5f08eb9be53910e3b9b2d02dd932f9b50bac10281272cdbaf8dee58d9/coverage-7.4.1-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "379d4c7abad5afbe9d88cc31ea8ca262296480a86af945b08214eb1a556a3e4d",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/3c/75/a4abb6a0d1d4814fbcf8d9e552fd08b579236d8f5c5bb4cfd8a566c43612/coverage-7.4.1-cp38-cp38-macosx_10_9_x86_64.whl",
            "8bdb0285a0202888d19ec6b6d23d5990410decb932b709f2b0dfe216d031d218",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/b3/b9/49b1028a69b1e9476db7508705fc67a1218ece54af07b87339eac1b5600a/coverage-7.4.1-cp38-cp38-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "f2f5968608b1fe2a1d00d01ad1017ee27efd99b3437e08b83ded9b7af3f6f766",
        ),
    },
    "cp39": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/ce/e1/df16e7e353c2ba5a5b3e02a6bad7dbf1bc62d5b9cfe5c06ed0e31fc64122/coverage-7.4.1-cp39-cp39-macosx_11_0_arm64.whl",
            "46342fed0fff72efcda77040b14728049200cbba1279e0bf1188f1f2078c1d70",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/86/25/6b70cb21b6e62158aab40a0e930361d4397f4ef4cbd2a04d3d01b6e4c5cf/coverage-7.4.1-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "9641e21670c68c7e57d2053ddf6c443e4f0a6e18e547e86af3fad0795414a628",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/9f/ae/0d439dc9adc0111ffbed38149d73ddf34f7a8768e377020181e624cf2634/coverage-7.4.1-cp39-cp39-macosx_10_9_x86_64.whl",
            "8e738a492b6221f8dcf281b67129510835461132b03024830ac0e554311a5c54",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/ff/e3/351477165426da841458f2c1b732360dd42da140920e3cd4b70676e5b77f/coverage-7.4.1-cp39-cp39-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "d12c923757de24e4e2110cf8832d83a886a4cf215c6e61ed506006872b43a6d1",
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
