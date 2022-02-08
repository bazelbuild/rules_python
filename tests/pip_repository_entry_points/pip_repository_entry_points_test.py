#!/usr/bin/env python3

import os
import subprocess
import unittest
from pathlib import Path


class PipRepositoryEntryPointsTest(unittest.TestCase):
    maxDiff = None

    def test_entry_point_void_return(self):
        env = os.environ.get("YAMLLINT_ENTRY_POINT")
        self.assertIsNotNone(env)

        entry_point = Path(env)
        self.assertTrue(entry_point.exists())

        proc = subprocess.run(
            [str(entry_point), "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(proc.stdout.decode("utf-8").strip(), "yamllint 1.26.3")

        # yamllint entry_point is of the form `def run(argv=None):`
        with self.assertRaises(subprocess.CalledProcessError) as context:
            subprocess.run(
                [str(entry_point), "--option-does-not-exist"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertIn("returned non-zero exit status 2", str(context.exception))

    def test_entry_point_int_return(self):
        env = os.environ.get("SPHINX_BUILD_ENTRY_POINT")
        self.assertIsNotNone(env)

        entry_point = Path(env)
        self.assertTrue(entry_point.exists())

        proc = subprocess.run(
            [str(entry_point), "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        # sphinx-build uses args[0] for its name, only assert the version here
        self.assertTrue(proc.stdout.decode("utf-8").strip().endswith("4.3.2"))

        # sphinx-build entry_point is of the form `def main(argv: List[str] = sys.argv[1:]) -> int:`
        with self.assertRaises(subprocess.CalledProcessError) as context:
            subprocess.run(
                [entry_point, "--option-does-not-exist"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertIn("returned non-zero exit status 2", str(context.exception))


if __name__ == "__main__":
    unittest.main()
