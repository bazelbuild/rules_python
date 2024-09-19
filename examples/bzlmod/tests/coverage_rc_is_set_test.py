# Copyright 2024 The Bazel Authors. All rights reserved.
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
import tempfile
import unittest


class TestEnvironmentVariables(unittest.TestCase):
    def test_coverage_rc_file_exists(self):
        # Assert that the environment variable is set and points to a valid file
        coverage_rc_path = os.environ.get("COVERAGE_RC")
        self.assertTrue(
            os.path.isfile(coverage_rc_path),
            "COVERAGE_RC does not point to a valid file",
        )

        # Read the content of the file and assert it matches the expected content
        expected_content = (
            "[report]\n"
            "include_namespace_packages=True\n"
            "skip_covered=True\n"
            "[run]\n"
            "relative_files=True\n"
            "branch=True\n"
        )

        with open(coverage_rc_path, "r") as file:
            file_content = file.read()

        self.assertEqual(
            file_content,
            expected_content,
            "COVERAGE_RC file content does not match the expected content",
        )


if __name__ == "__main__":
    unittest.main()
