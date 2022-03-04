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
import unittest


class TestPythonVersion(unittest.TestCase):
    def test_match_toolchain(self):
        stream = os.popen("bazel run @python_toolchain_host//:python3 -- --version")
        output = stream.read()
        self.assertEqual(output, "Python %python_version%\n")

        subprocess.run("bazel test //...", shell=True, check=True)


if __name__ == "__main__":
    os.chdir("%test_location%")
    python_version_test_dirname = os.path.dirname(os.path.realpath("python_version_test.py"))
    rules_python_path = os.path.join(python_version_test_dirname, "..", "..", "..", "..")
    with open(".bazelrc", "w") as bazelrc:
        bazelrc.write("build --override_repository rules_python=\"{}\"\n".format(rules_python_path))
        bazelrc.write("build --test_output=errors\n")
    unittest.main()
