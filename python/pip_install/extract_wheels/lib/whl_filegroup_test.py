import os
import unittest
import tempfile
from pathlib import Path

import shutil

from python.pip_install.extract_wheels.lib import bazel


class TestExtractWheel(unittest.TestCase):
    def setUp(self):
        self.original_workdir = Path(os.getcwd())
        self.extraction_dir = tempfile.mkdtemp()
        os.chdir(self.extraction_dir)
        self.wheel_path = Path("examples/wheel/example_minimal_package-0.0.1-py3-none-any.whl")
        shutil.copy(str(self.original_workdir / self.wheel_path), self.wheel_path.name)

    def tearDown(self):
        os.chdir(self.original_workdir)
        shutil.rmtree(self.extraction_dir)

    def test_generated_build_file_has_filegroup_target(self) -> None:
        generated_bazel_dir = bazel.extract_wheel(
            self.wheel_path.name,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
        )[2:]  # Take off the leading // from the returned label.
        # Assert that the raw wheel ends up in the package.
        self.assertIn(self.wheel_path.name, os.listdir(generated_bazel_dir))
        # Original file should be deleted from the root dir.
        self.assertNotIn(self.wheel_path.name, os.listdir(os.getcwd()))
        with open("{}/BUILD.bazel".format(generated_bazel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn('filegroup', build_file_content)

    def test_extract_wheel_incremental(self) -> None:
        generated_bazel_dir = bazel.extract_wheel(
            self.wheel_path.name,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
            incremental=True,
            incremental_repo_prefix="pypi__",
        )[2:]  # Take off the leading // from the returned label.
        # Assert that the raw wheel ends up in the package.
        self.assertIn(self.wheel_path.name, os.listdir(generated_bazel_dir))
        with open("{}/BUILD.bazel".format(generated_bazel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn('filegroup', build_file_content)



if __name__ == "__main__":
    unittest.main()
