import os
import unittest

from python.pip_install.extract_wheels.lib import bazel


class TestExtractWheel(unittest.TestCase):
    def test_generated_build_file_has_filegroup_target(self) -> None:
        wheel_name = "example_minimal_package-0.0.1-py3-none-any.whl"
        wheel_dir = "experimental/examples/wheel/"
        wheel_path = wheel_dir + wheel_name
        generated_bazel_dir = bazel.extract_wheel(
            wheel_path,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
        )[2:]  # Take off the leading // from the returned label.
        # Assert that the raw wheel ends up in the package.
        self.assertIn(wheel_name, os.listdir(generated_bazel_dir))
        with open("{}/BUILD".format(generated_bazel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn('filegroup', build_file_content)


if __name__ == "__main__":
    unittest.main()
