"""
Configures the execution environment for the wheel_tool so that it can consume the dependencies we vendor and create
reproducible wheels
"""
import os
import sys


def configure_vendor():
    """
    The dependencies we vendor need to be added to be added to the PYTHONPATH. We add the root of our vendor tree
    `third_party` which enables the modules to find their own dependencies as expected.
    """
    _this_file = __file__
    if (_this_file is None) or not os.path.isfile(_this_file):
        sys.exit("wheel_wrapper.py failed.  Cannot determine __file__")

    _tool_dir = os.path.dirname(_this_file)
    _root_dir = os.path.abspath(os.path.join(_tool_dir, ".."))

    # This prepends the vendor directory to the sys.path so that we preference their use over any system modules.
    sys.path[0:0] = [
        os.path.join(_root_dir, "third_party/python"),
        os.path.join(_root_dir, "."),
    ]

    # Pip creates python subprocesses, so we need to add the new path to the PYTHONPATH
    os.environ["PYTHONPATH"] = os.pathsep.join(sys.path)


def configure_reproducible_wheels():
    """
    Wheels created from sdists are not reproducible by default. We can however workaround this by
    patching in some configuration with environment variables.
    """

    # wheel, by default, enables debug symbols in GCC. This incidentally captures the build path in the .so file
    # We can override this behavior by disabling debug symbols entirely.
    # https://github.com/pypa/pip/issues/6505
    if os.environ.get("CFLAGS") is not None:
        os.environ["CFLAGS"] += " -g0"
    else:
        os.environ["CFLAGS"] = "-g0"

    # set SOURCE_DATE_EPOCH to 1980 so that we can use python wheels
    # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/python.section.md#python-setuppy-bdist_wheel-cannot-create-whl
    if os.environ.get("SOURCE_DATE_EPOCH") is None:
        os.environ["SOURCE_DATE_EPOCH"] = "315532800"

    # Python wheel metadata files can be unstable.
    # See https://bitbucket.org/pypa/wheel/pull-requests/74/make-the-output-of-metadata-files/diff
    if os.environ.get("PYTHONHASHSEED") is None:
        os.environ["PYTHONHASHSEED"] = "0"


def main():
    configure_vendor()
    configure_reproducible_wheels()

    # This must be imported after vendoring has been configured. As it tries to resolve its own dependencies
    import src.extract_wheels as whl

    whl.main()


if __name__ == "__main__":
    main()
