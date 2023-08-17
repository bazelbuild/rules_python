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
import sys
import unittest

from lib import main


class ExampleTest(unittest.TestCase):
    def test_coverage_doesnt_shadow_stdlib(self):
        # When we try to import the html module
        import html as html_stdlib

        try:
            import coverage.html as html_coverage
        except ImportError:
            self.skipTest("not running under coverage, skipping")

        self.assertEqual(
            "html",
            f"{html_stdlib.__name__}",
            "'html' from stdlib was not loaded correctly",
        )

        self.assertEqual(
            "coverage.html",
            f"{html_coverage.__name__}",
            "'coverage.html' was not loaded correctly",
        )

        self.assertNotEqual(
            html_stdlib,
            html_coverage,
            "'html' import should not be shadowed by coverage",
        )

    def test_coverage_sys_path(self):
        all_paths = ",\n    ".join(sys.path)

        for i, path in enumerate(sys.path[1:-2]):
            self.assertFalse(
                "/coverage" in path,
                f"Expected {i + 2}th '{path}' to not contain 'coverage.py' paths, "
                f"sys.path has {len(sys.path)} items:\n    {all_paths}",
            )

        first_item, last_item = sys.path[0], sys.path[-1]
        self.assertFalse(
            first_item.endswith("coverage"),
            f"Expected the first item in sys.path '{first_item}' to not be related to coverage",
        )
        if os.environ.get("COVERAGE_MANIFEST"):
            # we are running under the 'bazel coverage :test'
            self.assertTrue(
                "_coverage" in last_item,
                f"Expected {last_item} to be related to coverage",
            )
            self.assertEqual(pathlib.Path(last_item).name, "coverage")
        else:
            self.assertFalse(
                "coverage" in last_item, f"Expected coverage tooling to not be present"
            )

    def test_main(self):
        self.assertEquals(
            """\
-  -
A  1
B  2
-  -""",
            main([["A", 1], ["B", 2]]),
        )


if __name__ == "__main__":
    unittest.main()
