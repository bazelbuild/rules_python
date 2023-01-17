"""Dependencies for coverage.py used by the hermetic toolchain.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# Update with './tools/update_coverage_deps.py <version>'
#START: managed by update_coverage_deps.py script
_coverage_deps = [
    (
        "pypi__coverage_cp310_aarch64-apple-darwin",
        "https://files.pythonhosted.org/packages/89/a2/cbf599e50bb4be416e0408c4cf523c354c51d7da39935461a9687e039481/coverage-6.5.0-cp310-cp310-macosx_11_0_arm64.whl",
        "784f53ebc9f3fd0e2a3f6a78b2be1bd1f5575d7863e10c6e12504f240fd06660",
    ),
    (
        "pypi__coverage_cp310_aarch64-unknown-linux-gnu",
        "https://files.pythonhosted.org/packages/15/b0/3639d84ee8a900da0cf6450ab46e22517e4688b6cec0ba8ab6f8166103a2/coverage-6.5.0-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        "b4a5be1748d538a710f87542f22c2cad22f80545a847ad91ce45e77417293eb4",
    ),
    (
        "pypi__coverage_cp310_x86_64-apple-darwin",
        "https://files.pythonhosted.org/packages/c4/8d/5ec7d08f4601d2d792563fe31db5e9322c306848fec1e65ec8885927f739/coverage-6.5.0-cp310-cp310-macosx_10_9_x86_64.whl",
        "ef8674b0ee8cc11e2d574e3e2998aea5df5ab242e012286824ea3c6970580e53",
    ),
    (
        "pypi__coverage_cp310_x86_64-pc-windows-msvc",
        "https://files.pythonhosted.org/packages/ae/a3/f45cb5d32de0751863945d22083c15eb8854bb53681b2e792f2066c629b9/coverage-6.5.0-cp310-cp310-win_amd64.whl",
        "59f53f1dc5b656cafb1badd0feb428c1e7bc19b867479ff72f7a9dd9b479f10e",
    ),
    (
        "pypi__coverage_cp310_x86_64-unknown-linux-gnu",
        "https://files.pythonhosted.org/packages/3c/7d/d5211ea782b193ab8064b06dc0cc042cf1a4ca9c93a530071459172c550f/coverage-6.5.0-cp310-cp310-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "af4fffaffc4067232253715065e30c5a7ec6faac36f8fc8d6f64263b15f74db0",
    ),
    (
        "pypi__coverage_cp38_aarch64-apple-darwin",
        "https://files.pythonhosted.org/packages/07/82/79fa21ceca9a9b091eb3c67e27eb648dade27b2c9e1eb23af47232a2a365/coverage-6.5.0-cp38-cp38-macosx_11_0_arm64.whl",
        "2198ea6fc548de52adc826f62cb18554caedfb1d26548c1b7c88d8f7faa8f6ba",
    ),
    (
        "pypi__coverage_cp38_aarch64-unknown-linux-gnu",
        "https://files.pythonhosted.org/packages/40/3b/cd68cb278c4966df00158811ec1e357b9a7d132790c240fc65da57e10013/coverage-6.5.0-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        "6c4459b3de97b75e3bd6b7d4b7f0db13f17f504f3d13e2a7c623786289dd670e",
    ),
    (
        "pypi__coverage_cp38_x86_64-apple-darwin",
        "https://files.pythonhosted.org/packages/05/63/a789b462075395d34f8152229dccf92b25ca73eac05b3f6cd75fa5017095/coverage-6.5.0-cp38-cp38-macosx_10_9_x86_64.whl",
        "d900bb429fdfd7f511f868cedd03a6bbb142f3f9118c09b99ef8dc9bf9643c3c",
    ),
    (
        "pypi__coverage_cp38_x86_64-pc-windows-msvc",
        "https://files.pythonhosted.org/packages/06/f1/5177428c35f331f118e964f727f79e3a3073a10271a644c8361d3cea8bfd/coverage-6.5.0-cp38-cp38-win_amd64.whl",
        "7ccf362abd726b0410bf8911c31fbf97f09f8f1061f8c1cf03dfc4b6372848f6",
    ),
    (
        "pypi__coverage_cp38_x86_64-unknown-linux-gnu",
        "https://files.pythonhosted.org/packages/bd/a0/e263b115808226fdb2658f1887808c06ac3f1b579ef5dda02309e0d54459/coverage-6.5.0-cp38-cp38-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "6b07130585d54fe8dff3d97b93b0e20290de974dc8177c320aeaf23459219c0b",
    ),
    (
        "pypi__coverage_cp39_aarch64-apple-darwin",
        "https://files.pythonhosted.org/packages/63/e9/f23e8664ec4032d7802a1cf920853196bcbdce7b56408e3efe1b2da08f3c/coverage-6.5.0-cp39-cp39-macosx_11_0_arm64.whl",
        "95203854f974e07af96358c0b261f1048d8e1083f2de9b1c565e1be4a3a48cfc",
    ),
    (
        "pypi__coverage_cp39_aarch64-unknown-linux-gnu",
        "https://files.pythonhosted.org/packages/18/95/27f80dcd8273171b781a19d109aeaed7f13d78ef6d1e2f7134a5826fd1b4/coverage-6.5.0-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        "b9023e237f4c02ff739581ef35969c3739445fb059b060ca51771e69101efffe",
    ),
    (
        "pypi__coverage_cp39_x86_64-apple-darwin",
        "https://files.pythonhosted.org/packages/ea/52/c08080405329326a7ff16c0dfdb4feefaa8edd7446413df67386fe1bbfe0/coverage-6.5.0-cp39-cp39-macosx_10_9_x86_64.whl",
        "633713d70ad6bfc49b34ead4060531658dc6dfc9b3eb7d8a716d5873377ab745",
    ),
    (
        "pypi__coverage_cp39_x86_64-pc-windows-msvc",
        "https://files.pythonhosted.org/packages/b6/08/a88a9f3a11bb2d97c7a6719535a984b009728433838fbc65766488867c80/coverage-6.5.0-cp39-cp39-win_amd64.whl",
        "fc2af30ed0d5ae0b1abdb4ebdce598eafd5b35397d4d75deb341a614d333d987",
    ),
    (
        "pypi__coverage_cp39_x86_64-unknown-linux-gnu",
        "https://files.pythonhosted.org/packages/6b/f2/919f0fdc93d3991ca074894402074d847be8ac1e1d78e7e9e1c371b69a6f/coverage-6.5.0-cp39-cp39-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
        "8f830ed581b45b82451a40faabb89c84e1a998124ee4212d440e9c6cf70083e5",
    ),
]
#END: managed by update_coverage_deps.py script

def install_coverage_deps():
    """Register the dependency for the coverage dep.
    """
    for name, url, sha256 in _coverage_deps:
        maybe(
            http_archive,
            name = name,
            build_file_content = """
py_library(
    name = "coverage",
    srcs = ["coverage/__main__.py"],
    data = glob(["coverage/*", "coverage/**/*.py", "coverage/*.so"]),
    visibility = ["//visibility:public"],
)
        """,
            sha256 = sha256,
            type = "zip",
            urls = [url],
        )
