import glob
import json
import pathlib
import sys
import zipfile


# Generator is the modules_mapping.json file generator.
class Generator:
    stdout = None
    stderr = None

    def __init__(self, stdout, stderr):
        self.stdout = stdout
        self.stderr = stderr

    # dig_wheel analyses the wheel .whl file determining the modules it provides
    # by looking at the directory structure.
    def dig_wheel(self, wheel):
        mapping = {}
        wheel_paths = glob.glob(wheel["path"])
        assert len(wheel_paths) != 0, "wheel not found for {}: searched for {}".format(
            wheel["name"],
            wheel["path"],
        )
        wheel_path = wheel_paths[0]
        assert (
            "UNKNOWN" not in wheel_path
        ), "unknown-named wheel found for {}: possibly bad compilation".format(
            wheel["name"],
        )
        with zipfile.ZipFile(wheel_path, "r") as zip_file:
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
                        mapping[module] = wheel["name"]
                    # Always index the module file.
                    if ext == ".so":
                        # Also remove extra metadata that is embeded as part of
                        # the file name as an extra extension.
                        ext = "".join(pathlib.Path(path).suffixes)
                    module = path[: -len(ext)].replace("/", ".")
                    mapping[module] = wheel["name"]
        return mapping

    # run is the entrypoint for the generator.
    def run(self, wheels):
        mapping = {}
        for wheel_json in wheels:
            wheel = json.loads(wheel_json)
            try:
                mapping.update(self.dig_wheel(wheel))
            except AssertionError as error:
                print(error, file=self.stderr)
                return 1
        mapping_json = json.dumps(mapping)
        print(mapping_json, file=self.stdout)
        self.stdout.flush()
        return 0


# is_metadata checks if the path is in a metadata directory.
# Ref: https://www.python.org/dev/peps/pep-0427/#file-contents.
def is_metadata(path):
    top_level = path.split("/")[0].lower()
    return top_level.endswith(".dist-info") or top_level.endswith(".data")


if __name__ == "__main__":
    wheels = sys.argv[1:]
    generator = Generator(sys.stdout, sys.stderr)
    exit(generator.run(wheels))
