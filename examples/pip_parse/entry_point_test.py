#!/usr/bin/env python3

from pathlib import Path
import subprocess
import unittest


class PipParseEntryPointTest(unittest.TestCase):
    def test_output(self):
        self.maxDiff = None

        entry_point = Path("external/pip_parsed_deps_pypi__wheel/rules_python_wheel_entry_point_wheel")
        self.assertTrue(entry_point.exists())

        proc = subprocess.run([entry_point, "version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.stdout.decode("utf-8").strip(), "wheel 0.37.0")


if __name__ == "__main__":
    unittest.main()
