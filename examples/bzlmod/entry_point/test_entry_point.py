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
import pathlib
import subprocess
import unittest

from python.runfiles import runfiles


class ExampleTest(unittest.TestCase):
    def test_entry_point(self):
        rlocation_path = os.environ.get("YAMLLINT_ENTRY_POINT")
        assert (
            rlocation_path is not None
        ), "expected 'YAMLLINT_ENTRY_POINT' env variable to be set to rlocation of the tool"

        entry_point = pathlib.Path(runfiles.Create().Rlocation(rlocation_path))
        self.assertTrue(entry_point.exists(), f"'{entry_point}' does not exist")

        proc = subprocess.run(
            [str(entry_point), "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(proc.stdout.decode("utf-8").strip(), "yamllint 1.28.0")


if __name__ == "__main__":
    unittest.main()
