#!/usr/bin/env python3

from pathlib import Path
import subprocess
import textwrap
import unittest


class PipParseEntryPointTest(unittest.TestCase):
    def test_output(self):
        self.maxDiff = None

        entry_point = Path("external/pip/pypi__yamllint/rules_python_wheel_entry_point_yamllint")
        self.assertTrue(entry_point.exists())

        proc = subprocess.run([entry_point, "--help"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.stdout.decode("utf-8").rstrip(), textwrap.dedent("""\
            usage: yamllint [-h] [-] [-c CONFIG_FILE | -d CONFIG_DATA]
                            [-f {parsable,standard,colored,github,auto}] [-s]
                            [--no-warnings] [-v]
                            [FILE_OR_DIR ...]

            A linter for YAML files. yamllint does not only check for syntax validity, but
            for weirdnesses like key repetition and cosmetic problems such as lines
            length, trailing spaces, indentation, etc.

            positional arguments:
              FILE_OR_DIR           files to check

            optional arguments:
              -h, --help            show this help message and exit
              -                     read from standard input
              -c CONFIG_FILE, --config-file CONFIG_FILE
                                    path to a custom configuration
              -d CONFIG_DATA, --config-data CONFIG_DATA
                                    custom configuration (as YAML source)
              -f {parsable,standard,colored,github,auto}, --format {parsable,standard,colored,github,auto}
                                    format for parsing output
              -s, --strict          return non-zero exit code on warnings as well as
                                    errors
              --no-warnings         output only error level problems
              -v, --version         show program's version number and exit
            """).rstrip())


if __name__ == "__main__":
    unittest.main()
