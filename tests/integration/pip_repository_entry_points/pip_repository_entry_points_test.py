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
import subprocess
import unittest
from pathlib import Path

from rules_python.python.runfiles import runfiles


class PipRepositoryEntryPointsTest(unittest.TestCase):
    maxDiff = None

    def test_entry_point_void_return(self):
        env = os.environ.get("YAMLLINT_ENTRY_POINT")
        self.assertIsNotNone(env)

        r = runfiles.Create()
        entry_point = Path(r.Rlocation(str(Path(*Path(env).parts[1:]))))
        self.assertTrue(entry_point.exists())

        proc = subprocess.run(
            [str(entry_point), "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(proc.stdout.decode("utf-8").strip(), "yamllint 1.28.0")

        # yamllint entry_point is of the form `def run(argv=None):`
        with self.assertRaises(subprocess.CalledProcessError) as context:
            subprocess.run(
                [str(entry_point), "--option-does-not-exist"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertIn("returned non-zero exit status 2", str(context.exception))

    def test_entry_point_int_return(self):
        env = os.environ.get("SPHINX_BUILD_ENTRY_POINT")
        self.assertIsNotNone(env)

        r = runfiles.Create()
        entry_point = Path(r.Rlocation(str(Path(*Path(env).parts[1:]))))
        self.assertTrue(entry_point.exists())

        proc = subprocess.run(
            [str(entry_point), "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        # sphinx-build uses args[0] for its name, only assert the version here
        self.assertTrue(proc.stdout.decode("utf-8").strip().endswith("4.3.2"))

        # sphinx-build entry_point is of the form `def main(argv: List[str] = sys.argv[1:]) -> int:`
        with self.assertRaises(subprocess.CalledProcessError) as context:
            subprocess.run(
                [entry_point, "--option-does-not-exist"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertIn("returned non-zero exit status 2", str(context.exception))


if __name__ == "__main__":
    unittest.main()
