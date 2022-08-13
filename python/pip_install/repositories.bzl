""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# Avoid a load from @bazel_skylib repository as users don't necessarily have it installed
load("//third_party/github.com/bazelbuild/bazel-skylib/lib:versions.bzl", "versions")

_RULE_DEPS = [
    (
        "pypi__build",
        "https://files.pythonhosted.org/packages/7a/24/ee8271da317b692fcb9d026ff7f344ac6c4ec661a97f0e2a11fa7992544a/build-0.8.0-py3-none-any.whl",
        "19b0ed489f92ace6947698c3ca8436cb0556a66e2aa2d34cd70e2a5d27cd0437",
    ),
    (
        "pypi__click",
        "https://files.pythonhosted.org/packages/76/0a/b6c5f311e32aeb3b406e03c079ade51e905ea630fc19d1262a46249c1c86/click-8.0.1-py3-none-any.whl",
        "fba402a4a47334742d782209a7c79bc448911afe1149d07bdabdf480b3e2f4b6",
    ),
    (
        "pypi__colorama",
        "https://files.pythonhosted.org/packages/44/98/5b86278fbbf250d239ae0ecb724f8572af1c91f4a11edf4d36a206189440/colorama-0.4.4-py2.py3-none-any.whl",
        "9f47eda37229f68eee03b24b9748937c7dc3868f906e8ba69fbcbdd3bc5dc3e2",
    ),
    (
        "pypi__installer",
        "https://files.pythonhosted.org/packages/1b/21/3e6ebd12d8dccc55bcb7338db462c75ac86dbd0ac7439ac114616b21667b/installer-0.5.1-py3-none-any.whl",
        "1d6c8d916ed82771945b9c813699e6f57424ded970c9d8bf16bbc23e1e826ed3",
    ),
    (
        "pypi__packaging",
        "https://files.pythonhosted.org/packages/05/8e/8de486cbd03baba4deef4142bd643a3e7bbe954a784dc1bb17142572d127/packaging-21.3-py3-none-any.whl",
        "ef103e05f519cdc783ae24ea4e2e0f508a9c99b2d4969652eed6a2e1ea5bd522",
    ),
    (
        "pypi__pep517",
        "https://files.pythonhosted.org/packages/f4/67/846c08e18fefb265a66e6fd5a34269d649b779718d9bf59622085dabd370/pep517-0.12.0-py2.py3-none-any.whl",
        "dd884c326898e2c6e11f9e0b64940606a93eb10ea022a2e067959f3a110cf161",
    ),
    (
        "pypi__pip",
        "https://files.pythonhosted.org/packages/84/25/5734a44897751d8bac6822efb819acda2d969bcc1b915bbd7d48102952cb/pip-22.2.1-py3-none-any.whl",
        "0bbbc87dfbe6eed217beff0021f8b7dea04c8f4a0baa9d31dc4cff281ffc5b2b",
    ),
    (
        "pypi__pip_tools",
        "https://files.pythonhosted.org/packages/bf/3a/a8b09ca5ea24e4ddfa4d2cdf885e8c6618a4b658b32553f897f948aa0f67/pip_tools-6.8.0-py3-none-any.whl",
        "3e5cd4acbf383d19bdfdeab04738b6313ebf4ad22ce49bf529c729061eabfab8",
    ),
    (
        "pypi__pyparsing",
        "https://files.pythonhosted.org/packages/6c/10/a7d0fa5baea8fe7b50f448ab742f26f52b80bfca85ac2be9d35cdd9a3246/pyparsing-3.0.9-py3-none-any.whl",
        "5026bae9a10eeaefb61dab2f09052b9f4307d44aee4eda64b309723d8d206bbc",
    ),
    (
        "pypi__setuptools",
        "https://files.pythonhosted.org/packages/7c/5b/3d92b9f0f7ca1645cba48c080b54fe7d8b1033a4e5720091d1631c4266db/setuptools-60.10.0-py3-none-any.whl",
        "782ef48d58982ddb49920c11a0c5c9c0b02e7d7d1c2ad0aa44e1a1e133051c96",
    ),
    (
        "pypi__tomli",
        "https://files.pythonhosted.org/packages/97/75/10a9ebee3fd790d20926a90a2547f0bf78f371b2f13aa822c759680ca7b9/tomli-2.0.1-py3-none-any.whl",
        "939de3e7a6161af0c887ef91b7d41a53e7c5a1ca976325f429cb46ea9bc30ecc",
    ),
    (
        "pypi__wheel",
        "https://files.pythonhosted.org/packages/27/d6/003e593296a85fd6ed616ed962795b2f87709c3eee2bca4f6d0fe55c6d00/wheel-0.37.1-py2.py3-none-any.whl",
        "4bdcd7d840138086126cd09254dc6195fb4fc6f01c050a1d7236f2630db1d22a",
    ),
    (
        "pypi__importlib_metadata",
        "https://files.pythonhosted.org/packages/d7/31/74dcb59a601b95fce3b0334e8fc9db758f78e43075f22aeb3677dfb19f4c/importlib_metadata-1.4.0-py2.py3-none-any.whl",
        "bdd9b7c397c273bcc9a11d6629a38487cd07154fa255a467bf704cd2c258e359",
    ),
    (
        "pypi__zipp",
        "https://files.pythonhosted.org/packages/f4/50/cc72c5bcd48f6e98219fc4a88a5227e9e28b81637a99c49feba1d51f4d50/zipp-1.0.0-py2.py3-none-any.whl",
        "8dda78f06bd1674bd8720df8a50bb47b6e1233c503a4eed8e7810686bde37656",
    ),
    (
        "pypi__more_itertools",
        "https://files.pythonhosted.org/packages/bd/3f/c4b3dbd315e248f84c388bd4a72b131a29f123ecacc37ffb2b3834546e42/more_itertools-8.13.0-py3-none-any.whl",
        "c5122bffc5f104d37c1626b8615b511f3427aa5389b94d61e5ef8236bfbc3ddb",
    ),
]

_GENERIC_WHEEL = """\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "lib",
    srcs = glob(["**/*.py"]),
    data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
)
"""

# Collate all the repository names so they can be easily consumed
all_requirements = [name for (name, _, _) in _RULE_DEPS]

def requirement(pkg):
    return "@pypi__" + pkg + "//:lib"

def pip_install_dependencies():
    """
    Fetch dependencies these rules depend on. Workspaces that use the pip_install rule can call this.

    (However we call it from pip_install, making it optional for users to do so.)
    """

    # We only support Bazel LTS and rolling releases.
    # Give the user an obvious error to upgrade rather than some obscure missing symbol later.
    # It's not guaranteed that users call this function, but it's used by all the pip fetch
    # repository rules so it's likely that most users get the right error.
    versions.check("4.0.0")

    for (name, url, sha256) in _RULE_DEPS:
        maybe(
            http_archive,
            name,
            url = url,
            sha256 = sha256,
            type = "zip",
            build_file_content = _GENERIC_WHEEL,
        )
