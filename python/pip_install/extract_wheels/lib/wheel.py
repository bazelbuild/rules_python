"""Utility class to inspect an extracted wheel directory"""
import email
import glob
import os
import stat
import zipfile
from typing import Dict, Optional, Set

import installer
import pkg_resources


def current_umask() -> int:
    """Get the current umask which involves having to set it temporarily."""
    mask = os.umask(0)
    os.umask(mask)
    return mask


def set_extracted_file_to_default_mode_plus_executable(path: str) -> None:
    """
    Make file present at path have execute for user/group/world
    (chmod +x) is no-op on windows per python docs
    """
    os.chmod(path, (0o777 & ~current_umask() | 0o111))


class Wheel:
    """Representation of the compressed .whl file"""

    def __init__(self, path: str):
        self._path = path

    @property
    def path(self) -> str:
        return self._path

    @property
    def name(self) -> str:
        # TODO Also available as installer.sources.WheelSource.distribution
        return str(self.metadata['Name'])

    @property
    def metadata(self) -> email.message.Message:
        with installer.sources.WheelFile.open(self.path) as wheel_source:
            metadata_contents = wheel_source.read_dist_info("METADATA")
            metadata = installer.utils.parse_metadata_file(metadata_contents)
        return metadata

    @property
    def version(self) -> str:
        # TODO Also available as installer.sources.WheelSource.version
        return str(self.metadata["Version"])

    def entry_points(self) -> Dict[str, tuple[str, str]]:
        """Returns the entrypoints defined in the current wheel

        See https://packaging.python.org/specifications/entry-points/ for more info

        Returns:
            Dict[str, Tuple[str, str]]: A mapping of the entry point's name to it's module and attribute
        """
        with installer.sources.WheelFile.open(self.path) as wheel_source:
            if "entry_points.txt" not in wheel_source.dist_info_filenames:
                return dict()

            entry_points_mapping = dict()
            entry_points_contents = wheel_source.read_dist_info("entry_points.txt")
            entry_points = installer.utils.parse_entrypoints(entry_points_contents)
            for script, module, attribute, kind in entry_points:
                if kind == "console":
                    entry_points_mapping[script] = (module, attribute)

            return entry_points_mapping

    def dependencies(self, extras_requested: Optional[Set[str]] = None) -> Set[str]:
        dependency_set = set()

        for wheel_req in self.metadata.get_all('Requires-Dist', list()):
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
            # The following logic is borrowed from Pip:
            # https://github.com/pypa/pip/blob/cc48c07b64f338ac5e347d90f6cb4efc22ed0d0b/src/pip/_internal/utils/unpacking.py#L240
            for info in whl.infolist():
                name = info.filename
                # Do not attempt to modify directories.
                if name.endswith("/") or name.endswith("\\"):
                    continue
                mode = info.external_attr >> 16
                # if mode and regular file and any execute permissions for
                # user/group/world?
                if mode and stat.S_ISREG(mode) and mode & 0o111:
                    name = os.path.join(directory, name)
                    set_extracted_file_to_default_mode_plus_executable(name)


def get_dist_info(wheel_dir: str) -> str:
    """ "Returns the relative path to the dist-info directory if it exists.

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
