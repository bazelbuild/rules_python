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
import shutil
import tempfile
import unittest
import unittest.mock
from pathlib import Path
from typing import Dict, List, Tuple

from python.pip_install.tools.wheel_installer import wheel_installer
from python.pip_install.tools.lib import annotation


class MockWheelInstance:
    """A mock for python.pip_install.extract_wheels.wheel.Wheel."""

    def __init__(
        self,
        name: str,
        version: str,
        path: str,
        dependencies: List[str],
        entry_points: Dict[str, Tuple[str, str]],
    ):
        self.name = name
        self.path = path
        self.version = version
        self.dependency_list = dependencies
        self.entry_point_dict = entry_points

    def dependencies(self, extras_requested):
        # Since the caller can customize the dependency list to their liking,
        # we don't need to act on the extras_requested.
        return set(self.dependency_list)

    def entry_points(self):
        return self.entry_point_dict

    def unzip(self, directory):
        # We don't care about actually generating any files for our purposes.
        pass


def parse_starlark(filename: os.PathLike) -> Dict[str, unittest.mock.MagicMock]:
    """Parses a Starlark file.
    Args:
        filename: The name of the file to parse as Starlark.
    Returns:
        A dictionary of MagicMock instances for each of the functions that was
        invoked in the Starlark file.
    """
    starlark_globals = {
        "filegroup": unittest.mock.MagicMock(),
        "glob": unittest.mock.MagicMock(return_value=["<glob()>"]),
        "load": unittest.mock.MagicMock(),
        "package": unittest.mock.MagicMock(),
        "py_binary": unittest.mock.MagicMock(),
        "py_library": unittest.mock.MagicMock(),
    }
    compiled_starlark = compile(Path(filename).read_text(), filename, "exec")
    eval(compiled_starlark, starlark_globals)
    return starlark_globals


class TestRequirementExtrasParsing(unittest.TestCase):
    def test_parses_requirement_for_extra(self) -> None:
        cases = [
            ("name[foo]", ("name", frozenset(["foo"]))),
            ("name[ Foo123 ]", ("name", frozenset(["Foo123"]))),
            (" name1[ foo ] ", ("name1", frozenset(["foo"]))),
            ("Name[foo]", ("name", frozenset(["foo"]))),
            ("name_foo[bar]", ("name-foo", frozenset(["bar"]))),
            (
                "name [fred,bar] @ http://foo.com ; python_version=='2.7'",
                ("name", frozenset(["fred", "bar"])),
            ),
            (
                "name[quux, strange];python_version<'2.7' and platform_version=='2'",
                ("name", frozenset(["quux", "strange"])),
            ),
            (
                "name; (os_name=='a' or os_name=='b') and os_name=='c'",
                (None, None),
            ),
            (
                "name@http://foo.com",
                (None, None),
            ),
        ]

        for case, expected in cases:
            with self.subTest():
                self.assertTupleEqual(
                    wheel_installer._parse_requirement_for_extra(case), expected
                )


class BazelTestCase(unittest.TestCase):
    def test_generate_entry_point_contents(self):
        got = wheel_installer._generate_entry_point_contents("sphinx.cmd.build", "main")
        want = """#!/usr/bin/env python3
import sys
from sphinx.cmd.build import main
if __name__ == "__main__":
    sys.exit(main())
"""
        self.assertEqual(got, want)

    def test_generate_entry_point_contents_with_shebang(self):
        got = wheel_installer._generate_entry_point_contents(
            "sphinx.cmd.build", "main", shebang="#!/usr/bin/python"
        )
        want = """#!/usr/bin/python
import sys
from sphinx.cmd.build import main
if __name__ == "__main__":
    sys.exit(main())
"""
        self.assertEqual(got, want)

    @unittest.mock.patch("python.pip_install.extract_wheels.wheel.Wheel")
    def test_extract_wheel(self, MockWheel):
        """Validates that extract_wheel generates the expected BUILD file.
        We don't really care about extracting a .whl file here so we mock that
        part. The interesting bit is the BUILD file generation.
        """
        # Create a dummy wheel that we pretend to extract.
        mock_wheel_instance = MockWheelInstance(
            name="test-wheel",
            version="1.2.3",
            path="path/to/test-wheel.whl",
            dependencies=["a", "b", "//a/dep/of:some_kind"],
            entry_points={
                "test_bin_entry": ("test_wheel.entry", "main"),
            },
        )
        MockWheel.return_value = mock_wheel_instance

        # Run the BUILD file generation code.
        wheel_installer._extract_wheel(
            wheel_file=mock_wheel_instance.path,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=True,
            repo_prefix="repo_prefix_",
            annotation=annotation.Annotation(
                {
                    "additive_build_content": [],
                    "copy_executables": {},
                    "copy_files": {},
                    "data": ["//some/extra:data"],
                    "data_exclude_glob": ["foo/bad.data.*"],
                    "srcs_exclude_glob": ["foo/bad.srcs.*"],
                    "excluded_deps": ["//a/dep/of:some_kind"],
                }
            ),
        )

        parsed_starlark = parse_starlark(self.tmpdir / "BUILD.bazel")

        # Validate the library target.
        self.assertListEqual(
            parsed_starlark["py_library"].mock_calls,
            [
                unittest.mock.call(
                    name="pkg",
                    srcs=["<glob()>"],
                    data=["//some/extra:data", "<glob()>"],
                    imports=["site-packages"],
                    deps=[
                        "@repo_prefix_a//:pkg",
                        "@repo_prefix_b//:pkg",
                    ],
                    tags=["pypi_name=test-wheel", "pypi_version=1.2.3"],
                ),
            ],
        )
        self.assertListEqual(
            parsed_starlark["glob"].mock_calls[3:],
            [
                unittest.mock.call(
                    ["site-packages/**/*.py"],
                    exclude=["foo/bad.srcs.*"],
                    allow_empty=True,
                ),
                unittest.mock.call(
                    ["site-packages/**/*"],
                    exclude=[
                        "**/* *",
                        "**/*.dist-info/RECORD",
                        "**/*.py",
                        "**/*.pyc",
                        "foo/bad.data.*",
                    ],
                ),
            ],
        )

        # Validate the entry point targets.
        self.assertListEqual(
            parsed_starlark["py_binary"].mock_calls,
            [
                unittest.mock.call(
                    name="rules_python_wheel_entry_point_test_bin_entry",
                    srcs=["rules_python_wheel_entry_point_test_bin_entry.py"],
                    imports=["."],
                    deps=["pkg"],
                ),
            ],
        )


class TestWhlFilegroup(unittest.TestCase):
    def setUp(self) -> None:
        self.wheel_name = "example_minimal_package-0.0.1-py3-none-any.whl"
        self.wheel_dir = tempfile.mkdtemp()
        self.wheel_path = os.path.join(self.wheel_dir, self.wheel_name)
        shutil.copy(os.path.join("examples", "wheel", self.wheel_name), self.wheel_dir)

    def tearDown(self):
        shutil.rmtree(self.wheel_dir)

    def test_wheel_exists(self) -> None:
        wheel_installer._extract_wheel(
            self.wheel_path,
            installation_dir=Path(self.wheel_dir),
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
            repo_prefix="prefix_",
        )

        self.assertIn(self.wheel_name, os.listdir(self.wheel_dir))
        with open("{}/BUILD.bazel".format(self.wheel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn("filegroup", build_file_content)


if __name__ == "__main__":
    unittest.main()
