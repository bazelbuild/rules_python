# Copyright 2021 The Bazel Authors. All rights reserved.
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
import unittest


class WheelTest(unittest.TestCase):
    def test_py_wheel(self):
        whl = os.path.join(
            os.environ["TEST_SRCDIR"],
            "rules_python",
            "examples",
            "multi_package",
            "example_multi_package-0.0.1-py3-none-any.whl")

        env = {
            "PYTHONUSERBASE": os.environ["TEST_SRCDIR"],
        }
        subprocess.run(
            [sys.executable, "-m", "pip", "--no-cache-dir", "--isolated",
                "install", "--user", whl],
            env=env,
            check=True)

        assert_script = os.path.join(
            os.environ["TEST_SRCDIR"],
            "rules_python",
            "examples",
            "multi_package",
            "tests",
            "py_wheel_assert_test.py")
        subprocess.run(
            [sys.executable, assert_script],
            env=env,
            check=True)


if __name__ == '__main__':
    unittest.main()
