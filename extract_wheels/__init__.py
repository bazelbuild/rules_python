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

from extract_wheels.lib import bazel, requirements


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
    parser.add_argument(
        "--repo",
        action="store",
        required=True,
        help="The external repo name to install dependencies. In the format '@{REPO_NAME}'",
    )
    parser.add_argument('--extra_pip_args', action='store',
                        help=('Extra arguments to pass down to pip.'))
    parser.add_argument(
        "--pip_data_exclude",
        action='store',
        help='Additional data exclusion parameters to add to the pip packages BUILD file.'
    )
    args = parser.parse_args()

    pip_args = [sys.executable, "-m", "pip", "wheel", "-r", args.requirements]
    if args.extra_pip_args:
        pip_args += args.extra_pip_args.strip("\"").split()
    # Assumes any errors are logged by pip so do nothing. This command will fail if pip fails
    subprocess.run(pip_args, check=True)

    extras = requirements.parse_extras(args.requirements)

    if args.pip_data_exclude:
        pip_data_exclude = json.loads(args.pip_data_exclude)["exclude"]
    else:
        pip_data_exclude = []

    targets = [
        '"%s%s"' % (args.repo, bazel.extract_wheel(whl, extras, pip_data_exclude))
        for whl in glob.glob("*.whl")
    ]

    with open("requirements.bzl", "w") as requirement_file:
        requirement_file.write(
            bazel.generate_requirements_file_contents(args.repo, targets)
        )
