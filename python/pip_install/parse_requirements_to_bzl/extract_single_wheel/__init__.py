import argparse
import sys
import glob
import subprocess
import json

from tempfile import NamedTemporaryFile

from python.pip_install.extract_wheels.lib import bazel, requirements, arguments
from python.pip_install.extract_wheels import configure_reproducible_wheels


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build and/or fetch a single wheel based on the requirement passed in"
    )
    parser.add_argument(
        "--requirement",
        action="store",
        required=True,
        help="A single PEP508 requirement specifier string.",
    )
    arguments.parse_common_args(parser)
    args = parser.parse_args()

    configure_reproducible_wheels()

    pip_args = [sys.executable, "-m", "pip", "--isolated", "wheel", "--no-deps"]
    if args.extra_pip_args:
        pip_args += json.loads(args.extra_pip_args)["args"]

    with NamedTemporaryFile(mode='wb') as requirement_file:
        requirement_file.write(args.requirement.encode("utf-8"))
        requirement_file.flush()
        # Requirement specific args like --hash can only be passed in a requirements file,
        # so write our single requirement into a temp file in case it has any of those flags.
        pip_args.extend(["-r", requirement_file.name])

        # Assumes any errors are logged by pip so do nothing. This command will fail if pip fails
        subprocess.run(pip_args, check=True)

    name, extras_for_pkg = requirements._parse_requirement_for_extra(args.requirement)
    extras = {name: extras_for_pkg} if extras_for_pkg and name else dict()

    if args.pip_data_exclude:
        pip_data_exclude = json.loads(args.pip_data_exclude)["exclude"]
    else:
        pip_data_exclude = []

    whl = next(iter(glob.glob("*.whl")))
    bazel.extract_wheel(
        whl,
        extras,
        pip_data_exclude,
        args.enable_implicit_namespace_pkgs,
        incremental=True,
        incremental_repo_prefix=bazel.whl_library_repo_prefix(args.repo)
    )
