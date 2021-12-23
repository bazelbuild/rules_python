#!/usr/bin/env python3

import os
import subprocess
import unittest
from glob import glob
from pathlib import Path


class PipRepositoryAnnotationsTest(unittest.TestCase):
    maxDiff = None

    def wheel_pkg_dir(self) -> str:
        env = os.environ.get("WHEEL_PKG_DIR")
        self.assertIsNotNone(env)
        return env

    def test_build_content_and_data(self):
        generated_file = (
            Path.cwd() / "external" / self.wheel_pkg_dir() / "generated_file.txt"
        )
        self.assertTrue(generated_file.exists())

        content = generated_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from build content file")

    def test_copy_files(self):
        copied_file = (
            Path.cwd() / "external" / self.wheel_pkg_dir() / "copied_content/file.txt"
        )
        self.assertTrue(copied_file.exists())

        content = copied_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from copied file")

    def test_copy_executables(self):
        executable = (
            Path.cwd()
            / "external"
            / self.wheel_pkg_dir()
            / "copied_content/executable.py"
        )
        self.assertTrue(executable.exists())

        proc = subprocess.run(
            [executable], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        stdout = proc.stdout.decode("utf-8").strip()
        self.assertEqual(stdout, "Hello world from copied executable")

    def test_data_exclude_glob(self):
        files = glob("external/" + self.wheel_pkg_dir() + "/wheel-*.dist-info/*")
        basenames = [Path(path).name for path in files]
        self.assertIn("WHEEL", basenames)
        self.assertNotIn("RECORD", basenames)


if __name__ == "__main__":
    unittest.main()
