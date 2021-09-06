#!/usr/bin/env python3

from pathlib import Path
import os
import subprocess
import unittest


class PipInstallTest(unittest.TestCase):
    maxDiff = None

    def test_entry_point(self):
        env = os.environ.get("WHEEL_ENTRY_POINT")
        self.assertIsNotNone(env)

        entry_point = Path(env)
        self.assertTrue(entry_point.exists())

        proc = subprocess.run([entry_point, "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.stdout.decode("utf-8").strip(), "yamllint 1.26.3")

    def test_data(self):
        env = os.environ.get("WHEEL_DATA_CONTENTS")
        self.assertIsNotNone(env)
        self.assertListEqual(
            env.split(" "),
            [
                "external/pip_parsed_deps_pypi__s3cmd/s3cmd-2.1.0.data/data/share/doc/packages/s3cmd/INSTALL.md",
                "external/pip_parsed_deps_pypi__s3cmd/s3cmd-2.1.0.data/data/share/doc/packages/s3cmd/LICENSE",
                "external/pip_parsed_deps_pypi__s3cmd/s3cmd-2.1.0.data/data/share/doc/packages/s3cmd/NEWS",
                "external/pip_parsed_deps_pypi__s3cmd/s3cmd-2.1.0.data/data/share/doc/packages/s3cmd/README.md",
                "external/pip_parsed_deps_pypi__s3cmd/s3cmd-2.1.0.data/data/share/man/man1/s3cmd.1",
                "external/pip_parsed_deps_pypi__s3cmd/s3cmd-2.1.0.data/scripts/s3cmd",
            ],
        )

    def test_dist_info(self):
        env = os.environ.get("WHEEL_DIST_INFO_CONTENTS")
        self.assertIsNotNone(env)
        self.assertListEqual(
            env.split(" "),
            [
                "external/pip_parsed_deps_pypi__requests/requests-2.25.1.dist-info/LICENSE",
                "external/pip_parsed_deps_pypi__requests/requests-2.25.1.dist-info/METADATA",
                "external/pip_parsed_deps_pypi__requests/requests-2.25.1.dist-info/RECORD",
                "external/pip_parsed_deps_pypi__requests/requests-2.25.1.dist-info/WHEEL",
                "external/pip_parsed_deps_pypi__requests/requests-2.25.1.dist-info/top_level.txt",
            ],
        )


if __name__ == "__main__":
    unittest.main()
