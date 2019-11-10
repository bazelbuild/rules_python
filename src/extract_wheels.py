import argparse
import glob
import os
import subprocess
import sys

from .wheel import Wheel

BUILD_TEMPLATE = """\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "{name}",
    srcs = glob(["**/*.py"]),
    data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
    deps = [{dependencies}],
)
"""


def sanitise_name(name):
    """
    There are certain requirements around Bazel labels that we need to consider.

    rules-python automatically adds the repository root to the PYTHONPATH, meaning a package that has the same name as
    a module is picked up. We workaround this by prefixing with `pypi__`. Alternatively we could require
    `--noexperimental_python_import_all_repositories` be set, however this breaks rules_docker.
    See: https://github.com/bazelbuild/bazel/issues/2636

    Due to restrictions on Bazel labels we also cannot allow hyphens. See https://github.com/bazelbuild/bazel/issues/6841
    """
    return "pypi__" + name.replace("-", "_").replace(".", "_").lower()


def extract_wheel(whl, directory, extras):
    """
    Unzips a wheel into the Bazel repository and creates the BUILD file

    :param whl: the Wheel object we are unpacking
    :param directory: the subdirectory of the external repo to unzip to
    :param extras: list of extras that we want to create targets for
    """

    whl.unzip(directory)

    with open(os.path.join(directory, "BUILD"), "w") as f:
        f.write(
            BUILD_TEMPLATE.format(
                name=sanitise_name(whl.name()),
                dependencies=",".join(
                    # Python libraries cannot have hyphen https://github.com/bazelbuild/bazel/issues/9171
                    [
                        '"//%s"' % sanitise_name(d)
                        for d in whl.dependencies(extras_requested=extras)
                    ]
                ),
            )
        )


def main():
    parser = argparse.ArgumentParser(
        description="Resolve and fetch artifacts transitively from PyPI"
    )
    parser.add_argument(
        "--requirements",
        action="store",
        help="Path to requirements.txt from where to install dependencies",
    )
    parser.add_argument(
        "--repo",
        action="store",
        help="The external repo name to install dependencies.",
    )
    args = parser.parse_args()

    # Assumes any errors are logged by pip so do nothing. This command will fail if pip fails
    subprocess.check_output(
        [sys.executable, "-m", "pip", "wheel", "-r", args.requirements]
    )

    targets = set()

    for wheel in [Wheel(whl) for whl in glob.glob("*.whl")]:
        whl_label = sanitise_name(wheel.name())
        os.mkdir(whl_label)
        extract_wheel(wheel, whl_label, [])
        targets.add('"{repo}//{name}"'.format(repo=args.repo, name=whl_label))
        os.remove(wheel.path())

    with open("requirements.bzl", "w") as f:
        f.write(
            """\
all_requirements = [{requirement_labels}]

def requirement(name):
    name_key = name.replace("-", "_").replace(".", "_").lower()
    return "{repo}//pypi__" + name_key
""".format(
                requirement_labels=",".join(targets), repo=args.repo
            )
        )


if __name__ == "__main__":
    main()
