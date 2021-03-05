"""extract_wheels

extract_wheels resolves and fetches artifacts transitively from the Python Package Index (PyPI) based on a
requirements.txt. It generates the required BUILD files to consume these packages as Python libraries.

Under the hood, it depends on the `pip wheel` command to do resolution, download, and compilation into wheels.
"""
import argparse
import glob
import os
import subprocess
import sys
import json

from python.pip_install.extract_wheels.lib import bazel, requirements, utilities


def configure_reproducible_wheels() -> None:
    """Modifies the environment to make wheel building reproducible.

    Wheels created from sdists are not reproducible by default. We can however workaround this by
    patching in some configuration with environment variables.
    """

    # wheel, by default, enables debug symbols in GCC. This incidentally captures the build path in the .so file
    # We can override this behavior by disabling debug symbols entirely.
    # https://github.com/pypa/pip/issues/6505
    if "CFLAGS" in os.environ:
        os.environ["CFLAGS"] += " -g0"
    else:
        os.environ["CFLAGS"] = "-g0"

    # set SOURCE_DATE_EPOCH to 1980 so that we can use python wheels
    # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/python.section.md#python-setuppy-bdist_wheel-cannot-create-whl
    if "SOURCE_DATE_EPOCH" not in os.environ:
        os.environ["SOURCE_DATE_EPOCH"] = "315532800"

    # Python wheel metadata files can be unstable.
    # See https://bitbucket.org/pypa/wheel/pull-requests/74/make-the-output-of-metadata-files/diff
    if "PYTHONHASHSEED" not in os.environ:
        os.environ["PYTHONHASHSEED"] = "0"


def main() -> None:
    """Main program.

    Exits zero on successful program termination, non-zero otherwise.
    """

    configure_reproducible_wheels()

    parser = argparse.ArgumentParser(
        description="Resolve and fetch artifacts transitively from PyPI"
    )
    parser.add_argument(
        "--requirements",
        action="store",
        required=True,
        help="Path to requirements.txt from where to install dependencies",
    )
    utilities.parse_common_args(parser)
    args = parser.parse_args()

    pip_args = [sys.executable, "-m", "pip", "--isolated", "wheel", "-r", args.requirements]
    if args.extra_pip_args:
        pip_args += json.loads(args.extra_pip_args)["args"]

    # Assumes any errors are logged by pip so do nothing. This command will fail if pip fails
    subprocess.run(pip_args, check=True)

    extras = requirements.parse_extras(args.requirements)

    if args.pip_data_exclude:
        pip_data_exclude = json.loads(args.pip_data_exclude)["exclude"]
    else:
        pip_data_exclude = []

    repo_label = "@%s" % args.repo

    targets = [
        '"%s%s"'
        % (
            repo_label,
            bazel.extract_wheel(
                whl, extras, pip_data_exclude, args.enable_implicit_namespace_pkgs
            ),
        )
        for whl in glob.glob("*.whl")
    ]

    with open("requirements.bzl", "w") as requirement_file:
        requirement_file.write(
            bazel.generate_requirements_file_contents(repo_label, targets)
        )
