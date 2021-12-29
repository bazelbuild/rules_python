import unittest

from python.pip_install.extract_wheels.lib.bazel import generate_entry_point_contents


class BazelTestCase(unittest.TestCase):
    def test_generate_entry_point_contents(self):
        got = generate_entry_point_contents("sphinx.cmd.build:main")
        want = """#!/usr/bin/env python3
import sys
from sphinx.cmd.build import main
if __name__ == "__main__":
    sys.exit(main())
"""
        self.assertEqual(got, want)

    def test_generate_entry_point_contents_with_shebang(self):
        got = generate_entry_point_contents(
            "sphinx.cmd.build:main", shebang="#!/usr/bin/python"
        )
        want = """#!/usr/bin/python
import sys
from sphinx.cmd.build import main
sys.exit(main())
"""
        self.assertEqual(got, want)
