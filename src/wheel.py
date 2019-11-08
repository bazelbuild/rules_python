import pkginfo
import zipfile
import pkg_resources


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
