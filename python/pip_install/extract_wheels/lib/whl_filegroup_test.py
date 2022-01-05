import os
import shutil
import tempfile
import unittest
from pathlib import Path

from python.pip_install.extract_wheels.lib import bazel


class TestWhlFilegroup(unittest.TestCase):
    def setUp(self) -> None:
        self.wheel_name = "example_minimal_package-0.0.1-py3-none-any.whl"
        self.wheel_dir = tempfile.mkdtemp()
        self.wheel_path = os.path.join(self.wheel_dir, self.wheel_name)
        shutil.copy(os.path.join("examples", "wheel", self.wheel_name), self.wheel_dir)

    def tearDown(self):
        shutil.rmtree(self.wheel_dir)

    def _run(
        self,
        repo_prefix: str,
        incremental: bool = False,
    ) -> None:
        generated_bazel_dir = bazel.extract_wheel(
            self.wheel_path,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
            incremental=incremental,
            repo_prefix=repo_prefix,
            incremental_dir=Path(self.wheel_dir),
        )
        # Take off the leading // from the returned label.
        # Assert that the raw wheel ends up in the package.
        generated_bazel_dir = (
            generated_bazel_dir[2:] if not incremental else self.wheel_dir
        )

        self.assertIn(self.wheel_name, os.listdir(generated_bazel_dir))
        with open("{}/BUILD.bazel".format(generated_bazel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn("filegroup", build_file_content)

    def test_nonincremental(self) -> None:
        self._run(repo_prefix="prefix_")

    def test_incremental(self) -> None:
        self._run(incremental=True, repo_prefix="prefix_")


if __name__ == "__main__":
    unittest.main()
