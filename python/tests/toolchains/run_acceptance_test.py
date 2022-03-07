# Copyright 2022 The Bazel Authors. All rights reserved.
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
import sys
import tempfile
import unittest


class TestPythonVersion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.chdir("%test_location%")
        python_version_test_dirname = os.path.dirname(
            os.path.realpath("python_version_test.py")
        )
        rules_python_path = os.path.normpath(
            os.path.join(python_version_test_dirname, "..", "..", "..", "..")
        )

        is_windows = "win" in sys.platform
        if is_windows:
            newline = "\r\n"
            os.environ["HOME"] = tempfile.mkdtemp()
            os.environ["LocalAppData"] = tempfile.mkdtemp()
        else:
            newline = "\n"

        with open(".bazelrc", "w") as bazelrc:
            bazelrc.write(
                newline.join(
                    [
                        'build --override_repository rules_python="{}"'.format(
                            rules_python_path.replace("\\", "/")
                        ),
                        "build --test_output=errors",
                    ]
                )
            )

    def test_match_toolchain(self):
        stream = os.popen("bazel run @python_toolchain_host//:python3 -- --version")
        output = stream.read().strip()
        self.assertEqual(output, "Python %python_version%")

        subprocess.run("bazel test //...", shell=True, check=True)


if __name__ == "__main__":
    unittest.main()
