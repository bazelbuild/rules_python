# Copyright 2018 The Bazel Authors. All rights reserved.
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

import unittest
from rules_python.experimental.rules_python import extract_requirements

# Assume buildifier is not applied to BUILD file
BUILD_FILES = [
    """
    py_library(
    name = "foo.py",
    srcs = ["foo.py", "other.py"],
    deps = [requirement("bar"), requirement("foo")],
)""",
    """
    py_library(
    name = "foo.py",
    srcs = [
    "foo.py", "other.py"
],
    deps = [
    requirement("bar"), requirement("foo")
],
)""",
    """
    py_library(
    name = "foo.py",
    srcs = ["foo.py",
    "other.py"
],
    deps = [
    requirement("bar"), requirement("foo")],
)""",
]


class ExtractRequirementTest(unittest.TestCase):
    def test_parse_build_file(self):
        """Assert srcs and deps are extracted from BUILD file."""
        expected = {"foo.py": {"foo", "bar"}, "other.py": {"foo", "bar"}}
        for build_file in BUILD_FILES:
            self.assertEqual(
                extract_requirements.parse_build_file(build_file), expected
            )

    def test_filter_dependencies(self):
        """Assert only direct dependencies are returned"""
        source_code = {
            "foo.py",
        }
        direct_dependencies = [{"foo.py": {"foo", "bar"}, "other.py": {"foo", "bar"}}]
        all_dependencies = [
            ("bar", "0.1"),
            ("bar_transitive1", "0.2"),
            ("bar_transitive2", "0.3"),
        ]
        self.assertEqual(
            extract_requirements.filter_dependencies(
                source_code, direct_dependencies, all_dependencies
            ),
            [("bar", "0.1")],
        )


if __name__ == "__main__":
    unittest.main()
