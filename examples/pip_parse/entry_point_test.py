#!/usr/bin/env python3

import os
import subprocess
import textwrap
import unittest


class PipParseEntryPointTest(unittest.TestCase):
    def test_output(self):
        self.maxDiff = None

        entry_point = os.environ.get("PIP_REPOSITORY_ENTRY_POINT")
        self.assertIsNotNone(entry_point)

        proc = subprocess.run([entry_point, "--help"], check=True, capture_output=True)
        self.assertEqual(proc.stdout.decode("utf-8").rstrip(), textwrap.dedent("""\
            usage: rules_python_wheel_entry_point_wheel.py [-h]
                                                           {unpack,pack,convert,version,help}
                                                           ...

            positional arguments:
              {unpack,pack,convert,version,help}
                                    commands
                unpack              Unpack wheel
                pack                Repack wheel
                convert             Convert egg or wininst to wheel
                version             Print version and exit
                help                Show this help

            optional arguments:
              -h, --help            show this help message and exit
            """).rstrip())


if __name__ == "__main__":
    unittest.main()
