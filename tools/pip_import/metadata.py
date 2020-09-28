import toml
import pkginfo
import configparser

from pkg_resources import Requirement, split_sections
from packaging.markers import Marker


class SetupConfig:
    def __init__(self, data):
        self._data = data

    def __getattr__(self, key):
        return getattr(self._data, key)

    def get(self, key, default=None):
        return self._data.get(key, default)

    @staticmethod
    def parse(data):
        parser = configparser.ConfigParser(
            comment_prefixes=('#'), inline_comment_prefixes=('#'))
        parser.read_string(data)

        data = {
            k: dict(parser.items(k))
            for k in parser.sections()
        }

        return SetupConfig(data)


class PackageMetadata:
    def __init__(self, metadata):
        self._metadata = metadata

    def __getattr__(self, key):
        return getattr(self._metadata, key)

    @staticmethod
    def parse(data):
        d = pkginfo.Distribution()
        d.parse(data)
        return PackageMetadata(d)


class PyProject:
    def __init__(self, data):
        self._data = data

    def __getattr__(self, key):
        return getattr(self._data, key)

    def get(self, key, **kwargs):
        return self._data.get(key, **kwargs)

    def build_system(self):
        return self._data.get('build-system', {})

    @staticmethod
    def parse(data):
        return PyProject(toml.loads(data))


class RequirementSet:
    def __init__(self, requirements):
        self.requirements = list(requirements)

    def __iter__(self):
        return iter(self.requirements)

    @staticmethod
    def parse(data):
        def parse_requirement(line, section_name):
            r = Requirement(line)

            section_name = section_name or ''
            parsed = section_name.split(':', 2)
            extra = parsed[0]
            markers = parsed[1] if len(parsed) > 1 else None

            markers = [r.marker, markers]

            if len(extra) > 0:
                markers.insert(0, 'extra == "%s"' % extra)

            markers = [str(m) for m in markers if m]

            if len(markers) > 0:
                r.marker = Marker(' and '.join(markers))
            else:
                r.marker = None

            return r

        return [
            parse_requirement(line, section_name)
            for section_name, lines
            in split_sections(data)
            for line in lines
        ]
