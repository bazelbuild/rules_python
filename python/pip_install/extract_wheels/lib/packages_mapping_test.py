import unittest
import json

from python.pip_install.extract_wheels.lib import bazel, wheel


class TestGeneratePackagesMappingContents(unittest.TestCase):
    def test(self) -> None:
        whls = [
            wheel.Wheel("experimental/examples/multi_package/example_multi_package-0.0.1-py3-none-any.whl"),
            wheel.Wheel("experimental/examples/wheel/example_minimal_package-0.0.1-py3-none-any.whl"),
        ]
        for whl in whls:
            whl.unzip(".")
        contents = bazel.generate_packages_mappping_contents(whls)
        parsed_contents = json.loads(contents)
        self.assertEqual(parsed_contents["bar"], "example_multi_package")
        self.assertEqual(parsed_contents["foo"], "example_multi_package")
        self.assertEqual(parsed_contents["example_minimal_package"], "example_minimal_package")


if __name__ == "__main__":
    unittest.main()
