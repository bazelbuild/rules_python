"""Utility class to inspect an extracted wheel directory"""
import glob
import os
import zipfile
from typing import Dict, Optional, List, Set

import pkg_resources
import pkginfo

from extract_wheels.lib import bazel, purelib


class Wheel:
    """Representation of the compressed .whl file"""

    def __init__(self, path: str):
        self._path = path

    @property
    def path(self) -> str:
        return self._path

    @property
    def name(self) -> str:
        return self.metadata.name

    @property
    def metadata(self) -> pkginfo.Wheel:
        return pkginfo.get_metadata(self.path)

    def dependencies(self, extras_requested: Optional[List[str]] = None) -> Set[str]:
        dependency_set = set()

        for wheel_req in self.metadata.requires_dist:
            req = pkg_resources.Requirement(wheel_req)  # type: ignore

            if req.marker is None or any(
                req.marker.evaluate({"extra": extra})
                for extra in extras_requested or [""]
            ):
                dependency_set.add(req.name)  # type: ignore

        return dependency_set

    def unzip(self, directory: str) -> None:
        with zipfile.ZipFile(self.path, "r") as whl:
            whl.extractall(directory)


def get_dist_info(wheel_dir: str) -> str:
    """"Returns the relative path to the dist-info directory if it exists.

    Args:
         wheel_dir: The root of the extracted wheel directory.

    Returns:
        Relative path to the dist-info directory if it exists, else, None.
    """
    dist_info_dirs = glob.glob(os.path.join(wheel_dir, "*.dist-info"))
    if not dist_info_dirs:
        raise ValueError(
            "No *.dist-info directory found. %s is not a valid Wheel." % wheel_dir
        )

    if len(dist_info_dirs) > 1:
        raise ValueError(
            "Found more than 1 *.dist-info directory. %s is not a valid Wheel."
            % wheel_dir
        )

    return dist_info_dirs[0]


def get_dot_data_directory(wheel_dir: str) -> Optional[str]:
    """Returns the relative path to the data directory if it exists.

    See: https://www.python.org/dev/peps/pep-0491/#the-data-directory

    Args:
         wheel_dir: The root of the extracted wheel directory.

    Returns:
        Relative path to the data directory if it exists, else, None.
    """

    dot_data_dirs = glob.glob(os.path.join(wheel_dir, "*.data"))
    if not dot_data_dirs:
        return None

    if len(dot_data_dirs) > 1:
        raise ValueError(
            "Found more than 1 *.data directory. %s is not a valid Wheel." % wheel_dir
        )

    return dot_data_dirs[0]


def parse_wheel_meta_file(wheel_dir: str) -> Dict[str, str]:
    """Parses the given WHEEL file into a dictionary.

    Args:
         wheel_dir: The file path of the WHEEL metadata file in dist-info.

    Returns:
        The WHEEL file mapped into a dictionary.
    """
    contents = {}
    with open(wheel_dir, "r") as wheel_file:
        for line in wheel_file:
            cleaned = line.strip()
            if not cleaned:
                continue
            try:
                key, value = cleaned.split(":", maxsplit=1)
                contents[key] = value.strip()
            except ValueError:
                raise RuntimeError(
                    "Encounted invalid line in WHEEL file: '%s'" % cleaned
                )
    return contents


def extract_wheel(wheel_file: str, extras: List[str]) -> str:
    """Extracts wheel into given directory and creates a py_library target.

    Args:
        wheel_file: the filepath of the .whl
        extras: a list of extras to add as dependencies for the installed wheel

    Returns:
        The Bazel label for the extracted wheel, in the form '//path/to/wheel'.
    """

    whl = Wheel(wheel_file)
    directory = bazel.sanitise_name(whl.name)

    os.mkdir(directory)
    whl.unzip(directory)

    # Note: Order of operations matters here
    purelib.spread_purelib_into_root(directory)
    bazel.setup_namespace_pkg_compatibility(directory)

    with open(os.path.join(directory, "BUILD"), "w") as build_file:
        build_file.write(
            bazel.generate_build_file_contents(
                bazel.sanitise_name(whl.name),
                [
                    '"//%s"' % bazel.sanitise_name(d)
                    for d in sorted(whl.dependencies(extras_requested=extras))
                ],
            )
        )

    os.remove(whl.path)

    return "//%s" % directory
