# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import subprocess
import unittest

from python.runfiles import runfiles


class InterpreterTest(unittest.TestCase):
    def setUp(self):
        r = runfiles.Create()
        self.interpreter = r.Rlocation("rules_python/python/bin/python3")

    def test_version(self):
        """Validates that we can successfully execute arbitrary code from the CLI."""
        expected_version = os.environ["EXPECTED_PYTHON_VERSION"]

        result = subprocess.check_output(
            [self.interpreter],
            text=True,
            input="\r".join(
                [
                    "import sys",
                    "v = sys.version_info",
                    "print(f'version: {v.major}.{v.minor}')",
                ]
            ),
        ).strip()
        self.assertEqual(result, f"version: {expected_version}")

    def test_json_tool(self):
        """Validates that we can successfully invoke a module from the CLI."""
        # Pass unformatted JSON to the json.tool module.
        result = subprocess.check_output(
            [
                self.interpreter,
                "-m",
                "json.tool",
            ],
            text=True,
            input='{"json":"obj"}',
        ).strip()
        # Validate that we get formatted JSON back.
        self.assertEqual(result, '{\n    "json": "obj"\n}')


if __name__ == "__main__":
    unittest.main()
