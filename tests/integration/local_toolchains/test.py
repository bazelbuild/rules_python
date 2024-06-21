import json
import pathlib
import sys
import unittest

from python.runfiles import runfiles


class LocalToolchainTest(unittest.TestCase):
    maxDiff = None

    def test_toolchains(self):
        self.assertEqual("/usr/bin/python3", sys.executable)


if __name__ == "__main__":
    unittest.main()
