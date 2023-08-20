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
import tempfile
import unittest

from python.runfiles import runfiles


class ExampleTest(unittest.TestCase):
    def __init__(self, *args, **kwargs):
        self.maxDiff = None

        super().__init__(*args, **kwargs)

    def test_pylint_entry_point_deps(self):
        rlocation_path = os.environ.get("ENTRY_POINT")
        assert (
            rlocation_path is not None
        ), "expected 'ENTRY_POINT' env variable to be set to rlocation of the tool"

        entry_point = pathlib.Path(runfiles.Create().Rlocation(rlocation_path))
        self.assertTrue(entry_point.exists(), f"'{entry_point}' does not exist")

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = pathlib.Path(tmpdir)
            script = tmpdir / "hello_world.py"
            script.write_text(
                """\
\"\"\"
a module to demonstrate the pylint-print checker
\"\"\"

if __name__ == "__main__":
    print("Hello, World!")
"""
            )

            proc = subprocess.run(
                [
                    str(entry_point),
                    str(script),
                    "--output-format=text",
                    "--load-plugins=pylint_print",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={
                    # otherwise it may try to create ${HOME}/.cache/pylint
                    "PYLINTHOME": os.environ["TMPDIR"],
                },
                cwd=tmpdir,
            )

        self.assertEqual(
            "",
            proc.stderr.decode("utf-8").strip(),
        )
        self.assertRegex(
            proc.stdout.decode("utf-8").strip(),
            "W8201: Logging should be used instead of the print\(\) function\. \(print-function\)",
        )


if __name__ == "__main__":
    unittest.main()
