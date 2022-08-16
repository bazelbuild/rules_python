"""Utility class to inspect an extracted wheel directory"""
import email
from typing import Dict, Optional, Set, Tuple

import installer
import pkg_resources
from pip._vendor.packaging.utils import canonicalize_name


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
        name = str(self.metadata["Name"])
        return canonicalize_name(name)

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

    def entry_points(self) -> Dict[str, Tuple[str, str]]:
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
            for script, module, attribute, script_section in entry_points:
                if script_section == "console":
                    entry_points_mapping[script] = (module, attribute)

            return entry_points_mapping

    def dependencies(self, extras_requested: Optional[Set[str]] = None) -> Set[str]:
        dependency_set = set()

        for wheel_req in self.metadata.get_all("Requires-Dist", []):
            req = pkg_resources.Requirement(wheel_req)  # type: ignore

            if req.marker is None or any(
                req.marker.evaluate({"extra": extra})
                for extra in extras_requested or [""]
            ):
                dependency_set.add(req.name)  # type: ignore

        return dependency_set

    def unzip(self, directory: str) -> None:
        installation_schemes = {
            "purelib": "/site-packages",
            "platlib": "/site-packages",
            "headers": "/include",
            "scripts": "/bin",
            "data": "/data",
        }
        destination = installer.destinations.SchemeDictionaryDestination(
            installation_schemes,
            # TODO Should entry_point scripts also be handled by installer rather than custom code?
            interpreter="/dev/null",
            script_kind="posix",
            destdir=directory,
        )

        with installer.sources.WheelFile.open(self.path) as wheel_source:
            installer.install(
                source=wheel_source,
                destination=destination,
                additional_metadata={
                    "INSTALLER": b"https://github.com/bazelbuild/rules_python",
                },
            )
