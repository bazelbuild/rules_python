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
load(
    "//python:versions.bzl",
    "MINOR_MAPPING",
    "PLATFORMS",
)

# Update with './tools/update_coverage_deps.py <version>'
#START: managed by update_coverage_deps.py script
_coverage_deps = {
    "cp310": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/89/a2/cbf599e50bb4be416e0408c4cf523c354c51d7da39935461a9687e039481/coverage-6.5.0-cp310-cp310-macosx_11_0_arm64.whl",
            "784f53ebc9f3fd0e2a3f6a78b2be1bd1f5575d7863e10c6e12504f240fd06660",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/15/b0/3639d84ee8a900da0cf6450ab46e22517e4688b6cec0ba8ab6f8166103a2/coverage-6.5.0-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "b4a5be1748d538a710f87542f22c2cad22f80545a847ad91ce45e77417293eb4",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/c4/8d/5ec7d08f4601d2d792563fe31db5e9322c306848fec1e65ec8885927f739/coverage-6.5.0-cp310-cp310-macosx_10_9_x86_64.whl",
            "ef8674b0ee8cc11e2d574e3e2998aea5df5ab242e012286824ea3c6970580e53",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/3c/7d/d5211ea782b193ab8064b06dc0cc042cf1a4ca9c93a530071459172c550f/coverage-6.5.0-cp310-cp310-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "af4fffaffc4067232253715065e30c5a7ec6faac36f8fc8d6f64263b15f74db0",
        ),
    },
    "cp311": {
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/36/f3/5cbd79cf4cd059c80b59104aca33b8d05af4ad5bf5b1547645ecee716378/coverage-6.5.0-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "c4ed2820d919351f4167e52425e096af41bfabacb1857186c1ea32ff9983ed75",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/50/cf/455930004231fa87efe8be06d13512f34e070ddfee8b8bf5a050cdc47ab3/coverage-6.5.0-cp311-cp311-macosx_10_9_x86_64.whl",
            "4a5375e28c5191ac38cca59b38edd33ef4cc914732c916f2929029b4bfb50795",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/6a/63/8e82513b7e4a1b8d887b4e85c1c2b6c9b754a581b187c0b084f3330ac479/coverage-6.5.0-cp311-cp311-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "a8fb6cf131ac4070c9c5a3e21de0f7dc5a0fbe8bc77c9456ced896c12fcdad91",
        ),
    },
    "cp38": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/07/82/79fa21ceca9a9b091eb3c67e27eb648dade27b2c9e1eb23af47232a2a365/coverage-6.5.0-cp38-cp38-macosx_11_0_arm64.whl",
            "2198ea6fc548de52adc826f62cb18554caedfb1d26548c1b7c88d8f7faa8f6ba",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/40/3b/cd68cb278c4966df00158811ec1e357b9a7d132790c240fc65da57e10013/coverage-6.5.0-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "6c4459b3de97b75e3bd6b7d4b7f0db13f17f504f3d13e2a7c623786289dd670e",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/05/63/a789b462075395d34f8152229dccf92b25ca73eac05b3f6cd75fa5017095/coverage-6.5.0-cp38-cp38-macosx_10_9_x86_64.whl",
            "d900bb429fdfd7f511f868cedd03a6bbb142f3f9118c09b99ef8dc9bf9643c3c",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/bd/a0/e263b115808226fdb2658f1887808c06ac3f1b579ef5dda02309e0d54459/coverage-6.5.0-cp38-cp38-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "6b07130585d54fe8dff3d97b93b0e20290de974dc8177c320aeaf23459219c0b",
        ),
    },
    "cp39": {
        "aarch64-apple-darwin": (
            "https://files.pythonhosted.org/packages/63/e9/f23e8664ec4032d7802a1cf920853196bcbdce7b56408e3efe1b2da08f3c/coverage-6.5.0-cp39-cp39-macosx_11_0_arm64.whl",
            "95203854f974e07af96358c0b261f1048d8e1083f2de9b1c565e1be4a3a48cfc",
        ),
        "aarch64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/18/95/27f80dcd8273171b781a19d109aeaed7f13d78ef6d1e2f7134a5826fd1b4/coverage-6.5.0-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
            "b9023e237f4c02ff739581ef35969c3739445fb059b060ca51771e69101efffe",
        ),
        "x86_64-apple-darwin": (
            "https://files.pythonhosted.org/packages/ea/52/c08080405329326a7ff16c0dfdb4feefaa8edd7446413df67386fe1bbfe0/coverage-6.5.0-cp39-cp39-macosx_10_9_x86_64.whl",
            "633713d70ad6bfc49b34ead4060531658dc6dfc9b3eb7d8a716d5873377ab745",
        ),
        "x86_64-unknown-linux-gnu": (
            "https://files.pythonhosted.org/packages/6b/f2/919f0fdc93d3991ca074894402074d847be8ac1e1d78e7e9e1c371b69a6f/coverage-6.5.0-cp39-cp39-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            "8f830ed581b45b82451a40faabb89c84e1a998124ee4212d440e9c6cf70083e5",
        ),
    },
}
#END: managed by update_coverage_deps.py script

_coverage_patch = Label("//python/private:coverage.patch")

def coverage_dep(name, python_version, platform, visibility, install = True):
    """Register a singe coverage dependency based on the python version and platform.

    Args:
        name: The name of the registered repository.
        python_version: The full python version.
        platform: The platform, which can be found in //python:versions.bzl PLATFORMS dict.
        visibility: The visibility of the coverage tool.
        install: should we install the dependency with a given name or generate the label
            of the bzlmod dependency fallback, which is hard-coded in MODULE.bazel?

    Returns:
        The label of the coverage tool if the platform is supported, otherwise - None.
    """
    if "windows" in platform:
        # NOTE @aignas 2023-01-19: currently we do not support windows as the
        # upstream coverage wrapper is written in shell. Do not log any warning
        # for now as it is not actionable.
        return None

    python_short_version = python_version.rpartition(".")[0]
    abi = python_short_version.replace("3.", "cp3")
    url, sha256 = _coverage_deps.get(abi, {}).get(platform, (None, ""))

    if url == None:
        # Some wheels are not present for some builds, so let's silently ignore those.
        return None

    if not install:
        # FIXME @aignas 2023-01-19: right now we use globally installed coverage
        # which has visibility set to public, but is hidden due to repo remapping.
        #
        # The name of the toolchain is not known when registering the coverage tooling,
        # so we use this as a workaround for now.
        return Label("@pypi__coverage_{abi}_{platform}//:coverage".format(
            abi = abi,
            platform = platform,
        ))

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

    return Label("@@{name}//:coverage".format(name = name))

def install_coverage_deps():
    """Register the dependency for the coverage dep.

    This is only used under bzlmod.
    """

    for python_version in MINOR_MAPPING.values():
        for platform in PLATFORMS.keys():
            if "windows" in platform:
                continue

            coverage_dep(
                name = "pypi__coverage_cp{version_no_dot}_{platform}".format(
                    version_no_dot = python_version.rpartition(".")[0].replace(".", ""),
                    platform = platform,
                ),
                python_version = python_version,
                platform = platform,
                visibility = ["//visibility:public"],
                install = True,
            )
