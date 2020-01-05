import os
import pkginfo
import zipfile
import pkg_resources
import glob

from typing import Dict, Optional


class Wheel(object):
    def __init__(self, path):
        self._path = path

    def path(self):
        return self._path

    def name(self):
        return self.metadata().name

    def metadata(self):
        return pkginfo.get_metadata(self.path())

    def dependencies(self, extras_requested=None):
        if not extras_requested:
            # Provide an extra to safely evaluate the markers
            # without matching any extra
            extras_requested = [""]

        dependency_set = set()

        for req in self.metadata().requires_dist:
            r = pkg_resources.Requirement(req)

            if r.marker is None or any(
                r.marker.evaluate({"extra": extra}) for extra in extras_requested
            ):
                dependency_set.add(r.name)

        return dependency_set

    def unzip(self, directory):
        with zipfile.ZipFile(self.path(), "r") as whl:
            whl.extractall(directory)


def get_dist_info(extracted_whl_directory) -> str:
    dist_info_dirs = glob.glob(os.path.join(extracted_whl_directory, "*.dist-info"))
    if not dist_info_dirs:
        raise ValueError(
            f"No *.dist-info directory found. {extracted_whl_directory} is not a valid Wheel."
        )
    elif len(dist_info_dirs) > 1:
        raise ValueError(
            f"Found more than 1 *.dist-info directory. {extracted_whl_directory} is not a valid Wheel."
        )
    else:
        dist_info = dist_info_dirs[0]
    return dist_info


def get_dot_data_directory(extracted_whl_directory) -> Optional[str]:
    # See: https://www.python.org/dev/peps/pep-0491/#the-data-directory
    dot_data_dirs = glob.glob(os.path.join(extracted_whl_directory, "*.data"))
    if not dot_data_dirs:
        return None
    elif len(dot_data_dirs) > 1:
        raise ValueError(
            f"Found more than 1 *.data directory. {extracted_whl_directory} is not a valid Wheel."
        )
    else:
        dot_data_dir = dot_data_dirs[0]
    return dot_data_dir


def parse_WHEEL_file(whl_file_path: str) -> Dict[str, str]:
    contents = {}
    with open(whl_file_path, "r") as f:
        for line in f:
            cleaned = line.strip()
            if not cleaned:
                continue
            try:
                key, value = cleaned.split(":", maxsplit=1)
                contents[key] = value.strip()
            except ValueError:
                raise RuntimeError(f"Encounted invalid line in WHEEL file: '{cleaned}'")
    return contents
