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
import textwrap
import unittest
from pathlib import Path

from python.pip_install.tools.lib.annotation import Annotation, AnnotationsMap
from python.runfiles import runfiles


class AnnotationsTestCase(unittest.TestCase):

    maxDiff = None

    def test_annotations_constructor(self) -> None:
        annotations_env = os.environ.get("MOCK_ANNOTATIONS")
        self.assertIsNotNone(annotations_env)

        r = runfiles.Create()

        annotations_path = Path(r.Rlocation("rules_python/{}".format(annotations_env)))
        self.assertTrue(annotations_path.exists())

        annotations_map = AnnotationsMap(annotations_path)
        self.assertListEqual(
            list(annotations_map.annotations.keys()),
            ["pkg_a", "pkg_b", "pkg_c", "pkg_d"],
        )

        collection = annotations_map.collect(["pkg_a", "pkg_b", "pkg_c", "pkg_d"])

        self.assertEqual(
            collection["pkg_a"],
            Annotation(
                {
                    "additive_build_content": None,
                    "copy_executables": {},
                    "copy_files": {},
                    "data": [],
                    "data_exclude_glob": [],
                    "srcs_exclude_glob": [],
                }
            ),
        )

        self.assertEqual(
            collection["pkg_b"],
            Annotation(
                {
                    "additive_build_content": None,
                    "copy_executables": {},
                    "copy_files": {},
                    "data": [],
                    "data_exclude_glob": ["*.foo", "*.bar"],
                    "srcs_exclude_glob": [],
                }
            ),
        )

        self.assertEqual(
            collection["pkg_c"],
            Annotation(
                {
                    # The `join` and `strip` here accounts for potential
                    # differences in new lines between unix and windows
                    # hosts.
                    "additive_build_content": "\n".join(
                        [
                            line.strip()
                            for line in textwrap.dedent(
                                """\
                cc_library(
                    name = "my_target",
                    hdrs = glob(["**/*.h"]),
                    srcs = glob(["**/*.cc"]),
                )
                """
                            ).splitlines()
                        ]
                    ),
                    "copy_executables": {},
                    "copy_files": {},
                    "data": [":my_target"],
                    "data_exclude_glob": [],
                    "srcs_exclude_glob": [],
                }
            ),
        )

        self.assertEqual(
            collection["pkg_d"],
            Annotation(
                {
                    "additive_build_content": None,
                    "copy_executables": {},
                    "copy_files": {},
                    "data": [],
                    "data_exclude_glob": [],
                    "srcs_exclude_glob": ["pkg_d/tests/**"],
                }
            ),
        )


if __name__ == "__main__":
    unittest.main()
