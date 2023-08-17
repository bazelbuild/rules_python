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

# START: maintained by 'bazel run //tools/private:update_coverage_deps'
_coverage_deps = {
    "cp310": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/3d/80/7060a445e1d2c9744b683dc935248613355657809d6c6b2716cdf4ca4766/coverage-7.2.7-cp310-cp310-macosx_11_0_arm64.whl",
            "6d040ef7c9859bb11dfeb056ff5b3872436e3b5e401817d87a31e1750b9ae2fb",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/b8/9d/926fce7e03dbfc653104c2d981c0fa71f0572a9ebd344d24c573bd6f7c4f/coverage-7.2.7-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "ba90a9563ba44a72fda2e85302c3abc71c5589cea608ca16c22b9804262aaeb6",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/01/24/be01e62a7bce89bcffe04729c540382caa5a06bee45ae42136c93e2499f5/coverage-7.2.7-cp310-cp310-macosx_10_9_x86_64.whl",
            "d39b5b4f2a66ccae8b7263ac3c8170994b65266797fb96cbbfd3fb5b23921db8",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/b4/bd/1b2331e3a04f4cc9b7b332b1dd0f3a1261dfc4114f8479bebfcc2afee9e8/coverage-7.2.7-cp310-cp310-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "31563e97dae5598556600466ad9beea39fb04e0229e61c12eaa206e0aa202063",
        ),
    },
    "cp311": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/67/d7/cd8fe689b5743fffac516597a1222834c42b80686b99f5b44ef43ccc2a43/coverage-7.2.7-cp311-cp311-macosx_11_0_arm64.whl",
            "5baa06420f837184130752b7c5ea0808762083bf3487b5038d68b012e5937dbe",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/8c/95/16eed713202406ca0a37f8ac259bbf144c9d24f9b8097a8e6ead61da2dbb/coverage-7.2.7-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "fdec9e8cbf13a5bf63290fc6013d216a4c7232efb51548594ca3631a7f13c3a3",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/c6/fa/529f55c9a1029c840bcc9109d5a15ff00478b7ff550a1ae361f8745f8ad5/coverage-7.2.7-cp311-cp311-macosx_10_9_x86_64.whl",
            "06a9a2be0b5b576c3f18f1a241f0473575c4a26021b52b2a85263a00f034d51f",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/a7/cd/3ce94ad9d407a052dc2a74fbeb1c7947f442155b28264eb467ee78dea812/coverage-7.2.7-cp311-cp311-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "63426706118b7f5cf6bb6c895dc215d8a418d5952544042c8a2d9fe87fcf09cb",
        ),
    },
    "cp38": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/28/d7/9a8de57d87f4bbc6f9a6a5ded1eaac88a89bf71369bb935dac3c0cf2893e/coverage-7.2.7-cp38-cp38-macosx_11_0_arm64.whl",
            "3d376df58cc111dc8e21e3b6e24606b5bb5dee6024f46a5abca99124b2229ef5",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/c8/e4/e6182e4697665fb594a7f4e4f27cb3a4dd00c2e3d35c5c706765de8c7866/coverage-7.2.7-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "5e330fc79bd7207e46c7d7fd2bb4af2963f5f635703925543a70b99574b0fea9",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/c6/fc/be19131010930a6cf271da48202c8cc1d3f971f68c02fb2d3a78247f43dc/coverage-7.2.7-cp38-cp38-macosx_10_9_x86_64.whl",
            "54b896376ab563bd38453cecb813c295cf347cf5906e8b41d340b0321a5433e5",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/44/55/49f65ccdd4dfd6d5528e966b28c37caec64170c725af32ab312889d2f857/coverage-7.2.7-cp38-cp38-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "8d13c64ee2d33eccf7437961b6ea7ad8673e2be040b4f7fd4fd4d4d28d9ccb1e",
        ),
    },
    "cp39": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/ca/0c/3dfeeb1006c44b911ee0ed915350db30325d01808525ae7cc8d57643a2ce/coverage-7.2.7-cp39-cp39-macosx_11_0_arm64.whl",
            "06fb182e69f33f6cd1d39a6c597294cff3143554b64b9825d1dc69d18cc2fff2",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/61/af/5964b8d7d9a5c767785644d9a5a63cacba9a9c45cc42ba06d25895ec87be/coverage-7.2.7-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "201e7389591af40950a6480bd9edfa8ed04346ff80002cec1a66cac4549c1ad7",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/88/da/495944ebf0ad246235a6bd523810d9f81981f9b81c6059ba1f56e943abe0/coverage-7.2.7-cp39-cp39-macosx_10_9_x86_64.whl",
            "537891ae8ce59ef63d0123f7ac9e2ae0fc8b72c7ccbe5296fec45fd68967b6c9",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/fe/57/e4f8ad64d84ca9e759d783a052795f62a9f9111585e46068845b1cb52c2b/coverage-7.2.7-cp39-cp39-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "6f48351d66575f535669306aa7d6d6f71bc43372473b54a832222803eb956fd1",
        ),
    },
}
# END: maintained by 'bazel run //tools/private:update_coverage_deps'

_coverage_patch = Label("//python/private:coverage.patch")

def coverage_dep(name, python_version, platform, visibility):
    """Register a singe coverage dependency based on the python version and platform.

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
