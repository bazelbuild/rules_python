#!/usr/bin/env python3
# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import os
import platform
import subprocess
import sys
import unittest
from pathlib import Path

from python.runfiles import runfiles


class PipWhlModsTest(unittest.TestCase):
    maxDiff = None

    def package_path(self) -> str:
        return "rules_python~override~pip~"

    def wheel_pkg_dir(self) -> Path:
        distinfo = os.environ.get("WHEEL_DISTINFO")
        self.assertIsNotNone(distinfo)
        return Path(distinfo.split(" ")[0]).parents[2]

    def rlocation(self, runfiles, dir: Path, *segments):
        absolute_path = dir
        for segment in segments:
            absolute_path = absolute_path / segment

        return runfiles.Rlocation(str(absolute_path.relative_to(dir.parent)))

    def test_build_content_and_data(self):
        r = runfiles.Create()
        rpath = self.rlocation(r, self.wheel_pkg_dir(), "generated_file.txt")
        generated_file = Path(rpath)
        self.assertTrue(generated_file.exists())

        content = generated_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from build content file")

    def test_copy_files(self):
        r = runfiles.Create()
        rpath = self.rlocation(r, self.wheel_pkg_dir(), "copied_content", "file.txt")
        copied_file = Path(rpath)
        self.assertTrue(copied_file.exists())

        content = copied_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from copied file")

    def test_copy_executables(self):
        executable_name = (
            "executable.exe" if platform.system() == "windows" else "executable.py"
        )

        r = runfiles.Create()
        rpath = self.rlocation(
            r, self.wheel_pkg_dir(), "copied_content", executable_name
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

    def test_data_exclude_glob(self):
        current_wheel_version = "0.40.0"

        r = runfiles.Create()
        wheel_pkg_dir = self.wheel_pkg_dir()
        dist_info_dir = f"wheel-{current_wheel_version}.dist-info"

        # Note: `METADATA` is important as it's consumed by https://docs.python.org/3/library/importlib.metadata.html
        # `METADATA` is expected to be there to show dist-info files are included in the runfiles.
        metadata_path = Path(
            self.rlocation(r, wheel_pkg_dir, "site-packages", dist_info_dir, "METADATA")
        )

        # However, `WHEEL` was explicitly excluded, so it should be missing
        wheel_path = Path(
            self.rlocation(r, wheel_pkg_dir, "site-packages", dist_info_dir, "WHEEL")
        )

        self.assertTrue(
            metadata_path.exists(), f"METADATA was not found in {metadata_path}"
        )
        self.assertTrue(wheel_path.exists(), f"WHEEL was not found in {wheel_path}")

    def requests_pkg_dir(self) -> Path:
        distinfo = os.environ.get("REQUESTS_DISTINFO")
        self.assertIsNotNone(distinfo)
        pkgdir = Path(distinfo.split(" ")[0]).parents[2]
        return pkgdir

    def test_extra(self):
        # This test verifies that annotations work correctly for pip packages with extras
        # specified, in this case requests[security].
        r = runfiles.Create()
        rpath = self.rlocation(r, self.requests_pkg_dir(), "generated_file.txt")

        generated_file = Path(rpath)
        self.assertTrue(generated_file.exists())

        content = generated_file.read_text().rstrip()
        self.assertEqual(content, "Hello world from requests")


if __name__ == "__main__":
    unittest.main()
