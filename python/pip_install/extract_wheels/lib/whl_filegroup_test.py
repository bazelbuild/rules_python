import os
import shutil
import tempfile
from typing import Optional
import unittest

from python.pip_install.extract_wheels.lib import bazel


class TestWhlFilegroup(unittest.TestCase):
    def setUp(self) -> None:
        self.wheel_name = "example_minimal_package-0.0.1-py3-none-any.whl"
        self.wheel_dir = tempfile.mkdtemp()
        self.wheel_path = os.path.join(self.wheel_dir, self.wheel_name)
        shutil.copy(
            os.path.join("examples", "wheel", self.wheel_name), self.wheel_dir
        )
        self.original_dir = os.getcwd()
        os.chdir(self.wheel_dir)

    def tearDown(self):
        shutil.rmtree(self.wheel_dir)
        os.chdir(self.original_dir)

    def _run(
        self,
        incremental: bool = False,
        incremental_repo_prefix: Optional[str] = None,
    ) -> None:
        generated_bazel_dir = bazel.extract_wheel(
            self.wheel_path,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
            incremental=incremental,
            incremental_repo_prefix=incremental_repo_prefix
        )[2:]  # Take off the leading // from the returned label.
        # Assert that the raw wheel ends up in the package.
        self.assertIn(self.wheel_name, os.listdir(generated_bazel_dir))
        with open("{}/BUILD.bazel".format(generated_bazel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn('filegroup', build_file_content)

    def test_nonincremental(self) -> None:
        self._run()

    def test_incremental(self) -> None:
        self._run(incremental=True, incremental_repo_prefix="test")


if __name__ == "__main__":
    unittest.main()
