#!/usr/bin/env python3

import os
import platform
import subprocess
import sys
import unittest
from pathlib import Path

from rules_python.python.runfiles import runfiles


class PipRepositoryAnnotationsTest(unittest.TestCase):
    maxDiff = None

    def wheel_pkg_dir(self) -> str:
        env = os.environ.get("WHEEL_PKG_DIR")
        self.assertIsNotNone(env)
        return env

    def test_build_content_and_data(self):
        r = runfiles.Create()
        rpath = r.Rlocation(
            "pip_repository_annotations_example/external/{}/generated_file.txt".format(
                self.wheel_pkg_dir()
            )
        )
        generated_file = Path(rpath)
        self.assertTrue(generated_file.exists())

        content = generated_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from build content file")

    def test_copy_files(self):
        r = runfiles.Create()
        rpath = r.Rlocation(
            "pip_repository_annotations_example/external/{}/copied_content/file.txt".format(
                self.wheel_pkg_dir()
            )
        )
        copied_file = Path(rpath)
        self.assertTrue(copied_file.exists())

        content = copied_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from copied file")

    def test_copy_executables(self):
        r = runfiles.Create()
        rpath = r.Rlocation(
            "pip_repository_annotations_example/external/{}/copied_content/executable{}".format(
                self.wheel_pkg_dir(),
                ".exe" if platform.system() == "windows" else ".py",
            )
        )
        executable = Path(rpath)
        self.assertTrue(executable.exists())

        proc = subprocess.run(
            [sys.executable, str(executable)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        stdout = proc.stdout.decode("utf-8").strip()
        self.assertEqual(stdout, "Hello world from copied executable")


if __name__ == "__main__":
    unittest.main()
