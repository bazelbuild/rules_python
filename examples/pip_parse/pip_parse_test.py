#!/usr/bin/env python3
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
import subprocess
import unittest
from pathlib import Path

from rules_python.python.runfiles import runfiles


class PipInstallTest(unittest.TestCase):
    maxDiff = None

    def test_entry_point(self):
        env = os.environ.get("YAMLLINT_ENTRY_POINT")
        self.assertIsNotNone(env)

        r = runfiles.Create()

        # To find an external target, this must use `{workspace_name}/$(rootpath @external_repo//:target)`
        entry_point = Path(r.Rlocation("rules_python_pip_parse_example/{}".format(env)))
        self.assertTrue(entry_point.exists())

        proc = subprocess.run(
            [str(entry_point), "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(proc.stdout.decode("utf-8").strip(), "yamllint 1.26.3")

    def test_data(self):
        env = os.environ.get("WHEEL_DATA_CONTENTS")
        self.assertIsNotNone(env)
        self.assertListEqual(
            env.split(" "),
            [
                "external/pypi_s3cmd/data/share/doc/packages/s3cmd/INSTALL.md",
                "external/pypi_s3cmd/data/share/doc/packages/s3cmd/LICENSE",
                "external/pypi_s3cmd/data/share/doc/packages/s3cmd/NEWS",
                "external/pypi_s3cmd/data/share/doc/packages/s3cmd/README.md",
                "external/pypi_s3cmd/data/share/man/man1/s3cmd.1",
            ],
        )

    def test_dist_info(self):
        env = os.environ.get("WHEEL_DIST_INFO_CONTENTS")
        self.assertIsNotNone(env)
        self.assertListEqual(
            env.split(" "),
            [
                "external/pypi_requests/site-packages/requests-2.25.1.dist-info/INSTALLER",
                "external/pypi_requests/site-packages/requests-2.25.1.dist-info/LICENSE",
                "external/pypi_requests/site-packages/requests-2.25.1.dist-info/METADATA",
                "external/pypi_requests/site-packages/requests-2.25.1.dist-info/RECORD",
                "external/pypi_requests/site-packages/requests-2.25.1.dist-info/WHEEL",
                "external/pypi_requests/site-packages/requests-2.25.1.dist-info/top_level.txt",
            ],
        )


if __name__ == "__main__":
    unittest.main()
