import os
import shutil
import tempfile
import unittest
from pathlib import Path

from python.pip_install.tools.wheel_installer import wheel_installer


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
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=False,
            repo_prefix="prefix_",
            incremental_dir=Path(self.wheel_dir),
        )

        self.assertIn(self.wheel_name, os.listdir(self.wheel_dir))
        with open("{}/BUILD.bazel".format(self.wheel_dir)) as build_file:
            build_file_content = build_file.read()
            self.assertIn("filegroup", build_file_content)


if __name__ == "__main__":
    unittest.main()
