"""
A tool that invokes pypa/build to build the given sdist tarball.

Copied from https://github.com/jvolkman/rules_pycross/blob/main/pycross/private/tools/wheel_installer.py
at commit 91e10c1f62926e8e9821897e252e359f797ff989.
"""

import argparse
import os
import subprocess
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

from installer import install
from installer.destinations import SchemeDictionaryDestination
from installer.sources import WheelFile


def main(args: Any) -> None:
    dest_dir = args.directory
    lib_dir = dest_dir / "site-packages"
    destination = SchemeDictionaryDestination(
        scheme_dict={
            "platlib": str(lib_dir),
            "purelib": str(lib_dir),
            "headers": str(dest_dir / "include"),
            "scripts": str(dest_dir / "bin"),
            "data": str(dest_dir / "data"),
        },
        interpreter="/usr/bin/env python3",  # Generic; it's not feasible to run these scripts directly.
        script_kind="posix",
        bytecode_optimization_levels=[0, 1],
    )

    link_dir = Path(tempfile.mkdtemp())
    if args.wheel_name_file:
        with open(args.wheel_name_file, "r") as f:
            wheel_name = f.read().strip()
    else:
        wheel_name = os.path.basename(args.wheel)

    link_path = link_dir / wheel_name
    os.symlink(os.path.join(os.getcwd(), args.wheel), link_path)

    try:
        with WheelFile.open(link_path) as source:
            install(
                source=source,
                destination=destination,
                # Additional metadata that is generated by the installation tool.
                additional_metadata={
                    "INSTALLER": b"https://github.com/jvolkman/rules_pycross",
                },
            )
    finally:
        shutil.rmtree(link_dir, ignore_errors=True)

    patch_args = [args.patch_tool] + args.patch_arg
    patch_dir = args.patch_dir or "."
    for patch in (args.patch or []):
        with patch.open("r") as stdin:
            subprocess.run(patch_args, stdin=stdin, check=True, cwd=args.directory / patch_dir)


def parse_flags(argv) -> Any:
    parser = argparse.ArgumentParser(description="Extract a Python wheel.")

    parser.add_argument(
        "--wheel",
        type=Path,
        required=True,
        help="The wheel file path.",
    )

    parser.add_argument(
        "--wheel-name-file",
        type=Path,
        required=False,
        help="A file containing the canonical name of the wheel.",
    )

    parser.add_argument(
        "--enable-implicit-namespace-pkgs",
        action="store_true",
        help="If true, disables conversion of implicit namespace packages and will unzip as-is.",
    )

    parser.add_argument(
        "--directory",
        type=Path,
        help="The output path.",
    )

    parser.add_argument(
        "--patch",
        type=Path,
        action="append",
        help="A patch file to apply.",
    )

    parser.add_argument(
        "--patch-arg",
        type=Path,
        action="append",
        help="An argument for the patch_tool when applying the patches.",
    )

    parser.add_argument(
        "--patch-tool",
        type=str,
        help="The tool to invoke when applying patches.",
    )

    parser.add_argument(
        "--patch-dir",
        type=str,
        help="The directory from which to invoke patch_tool.",
    )

    return parser.parse_args(argv[1:])


if __name__ == "__main__":
    # When under `bazel run`, change to the actual working dir.
    if "BUILD_WORKING_DIRECTORY" in os.environ:
        os.chdir(os.environ["BUILD_WORKING_DIRECTORY"])

    args = parse_flags(sys.argv)
    main(args)
