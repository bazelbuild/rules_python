# Requirements for building our piptool.
load(
    "@piptool_deps//:requirements.bzl",
    _piptool_install = "pip_install",
)

# Imports for examples.
load(
    "@examples_helloworld//:requirements.bzl",
    _helloworld_install = "pip_install",
)
load(
    "@examples_version//:requirements.bzl",
    _version_install = "pip_install",
)
load(
    "@examples_boto//:requirements.bzl",
    _boto_install = "pip_install",
)
load(
    "@examples_extras//:requirements.bzl",
    _extras_install = "pip_install",
)


def rules_python_internal_setup():
    # Requirements for building our piptool.
    _piptool_install()

    # Imports for examples.
    _helloworld_install()
    _version_install()
    _boto_install()
    _extras_install()
