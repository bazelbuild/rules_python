import json
import pathlib
import sys
import zipfile


# Generator is the modules_mapping.json file generator.
class Generator:
    stderr = None
    output_file = None

    def __init__(self, stderr, output_file):
        self.stderr = stderr
        self.output_file = output_file

    # dig_wheel analyses the wheel .whl file determining the modules it provides
    # by looking at the directory structure.
    def dig_wheel(self, whl):
        mapping = {}
        wheel_name = get_wheel_name(whl)
        with zipfile.ZipFile(whl, "r") as zip_file:
            for path in zip_file.namelist():
                if is_metadata(path):
                    continue
                ext = pathlib.Path(path).suffix
                if ext == ".py" or ext == ".so":
                    # Note the '/' here means that the __init__.py is not in the
                    # root of the wheel, therefore we can index the directory
                    # where this file is as an importable package.
                    if path.endswith("/__init__.py"):
                        module = path[: -len("/__init__.py")].replace("/", ".")
                        mapping[module] = wheel_name
                    # Always index the module file.
                    if ext == ".so":
                        # Also remove extra metadata that is embeded as part of
                        # the file name as an extra extension.
                        ext = "".join(pathlib.Path(path).suffixes)
                    module = path[: -len(ext)].replace("/", ".")
                    mapping[module] = wheel_name
        return mapping

    # run is the entrypoint for the generator.
    def run(self, wheels):
        mapping = {}
        for whl in wheels:
            try:
                mapping.update(self.dig_wheel(whl))
            except AssertionError as error:
                print(error, file=self.stderr)
                return 1
        mapping_json = json.dumps(mapping)
        with open(self.output_file, "w") as f:
            f.write(mapping_json)
        return 0


def get_wheel_name(path):
    pp = pathlib.PurePath(path)
    if pp.suffix != ".whl":
        raise RuntimeError(
            "{} is not a valid wheel file name: the wheel doesn't follow ".format(
                pp.name
            )
            + "https://www.python.org/dev/peps/pep-0427/#file-name-convention"
        )
    return pp.name[: pp.name.find("-")]


# is_metadata checks if the path is in a metadata directory.
# Ref: https://www.python.org/dev/peps/pep-0427/#file-contents.
def is_metadata(path):
    top_level = path.split("/")[0].lower()
    return top_level.endswith(".dist-info") or top_level.endswith(".data")


if __name__ == "__main__":
    output_file = sys.argv[1]
    wheels = sys.argv[2:]
    generator = Generator(sys.stderr, output_file)
    exit(generator.run(wheels))
