import argparse
import glob
import os
import subprocess
import sys
import zipfile

import pkginfo
import pip._internal.main as pip

import pkg_resources


# Normalises package names to be used in Bazel labels.
def sanitise_package(name):
    return name.replace("-", "_").lower()


class Wheel(object):
    def __init__(self, path):
        self._path = path

    def path(self):
        return self._path

    def name(self):
        return self.metadata().name

    def metadata(self):
        return pkginfo.get_metadata(self.path())

    def dependencies(self, extra=None):
        dependency_set = set()

        for req in [pkg_resources.Requirement.parse(req) for req in self.metadata().requires_dist]:
            if extra is None and req.marker is None:
                dependency_set.add(req.name)
            elif req.marker is not None and req.marker.evaluate({"extra": extra}):
                dependency_set.add(req.name)

        return dependency_set

    def expand(self, directory):
        with zipfile.ZipFile(self.path(), "r") as whl:
            whl.extractall(directory)


def extract_wheel(whl, directory, extras):
    """
    Unzips a wheel into the Bazel repository and creates the BUILD file

    :param whl: the Wheel object we are unpacking
    :param directory: the subdirectory of the external repo to unzip to
    :param extras: list of extras that we want to create targets for
    """

    whl.expand(directory)

    # Extract the files into the current directory
    with open(os.path.join(directory, "BUILD"), "w") as f:
        f.write(
            """\
package(default_visibility = ["//visibility:public"])

load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "pkg",
    srcs = glob(["**/*.py"]),
    data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
    deps = [{dependencies}],
)

{extras}
""".format(
                dependencies=",".join(
                    ['"//%s:pkg"' % (sanitise_package(d)) for d in whl.dependencies()]
                ),
                # TODO(dillon): We don't provide a mechanism to consume the library and all of its extras.
                extras="\n".join(
                    [
                        """\
py_library(
    name = "{extra}",
    deps = [
        ":pkg",{deps}
    ],
)""".format(
                            extra=extra,
                            deps=",".join(
                                [
                                    '"//%s:pkg"' % (sanitise_package(dep))
                                    for dep in whl.dependencies(extra)
                                ]
                            ),
                        )
                        for extra in extras or []
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

    # Pip automatically downloads and compiles the wheels for extra packages defined in requirements.txt
    # Unfortunately are dependency information is retrieved from the *package*dist-info/METADATA file.
    # To correctly wire up extra dependencies, we need to scrape the requirements.txt file.
    #
    # There is no good library to parse this file so we do some rudimentary try-except on the individual lines
    requirements = {}
    req_file = open(args.requirements, "r")
    for r in req_file:
        try:
            req = Requirement.parse(r)
            requirements[req.name] = req
        except:
            # At this point we log and continue. It is assumed pip will fail if the file is actually incorrect
            print("Failed to parse requirement %s" % r)

    # Assumes any errors are logged by pip so do nothing
    if pip.main(["wheel", "-r", args.requirements]):
        sys.exit(1)

    for whl_file in glob.glob("*.whl"):
        whl_dir = str(whl_file).lower().split("-")[0]
        os.mkdir(whl_dir)
        wheel = Wheel(whl_file)

        wheel_req = requirements.get(wheel.name())
        extras = wheel_req.extras if wheel_req is not None else []

        extract_wheel(wheel, whl_dir, extras)
        os.remove(whl_file)

    targets = ",".join(
        [
            '"%s//%s:pkg"' % (args.repo, sanitise_package(package))
            for package in requirements
        ]
    )

    with open("requirements.bzl", "w") as f:
        f.write(
            """\
all_requirements = [{requirement_labels}]

def requirement(name):
    name_key = name.replace("-", "_").lower()
    return "{repo}//" + name_key + ":pkg"
""".format(
                repo=args.repo, requirement_labels=targets
            )
        )


if __name__ == "__main__":
    main()
