"""Setup for rules_python tests and tools."""

# Requirements for building our piptool.
load(
    "@piptool_deps//:requirements.bzl",
    _piptool_install = "pip_install",
)

def rules_python_internal_setup():
    """Setup for rules_python tests and tools."""

    # Requirements for building our piptool.
    _piptool_install()
