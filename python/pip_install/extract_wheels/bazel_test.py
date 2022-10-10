import os
import shutil
import unittest
import unittest.mock
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from python.pip_install.extract_wheels import annotation
from python.pip_install.extract_wheels.bazel import (
    extract_wheel,
    generate_entry_point_contents,
)


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


class BazelTestCase(unittest.TestCase):
    def setUp(self):
        self.tmpdir = Path(os.environ["TEST_TMPDIR"]) / "tmpdir"
        self.tmpdir.mkdir()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_generate_entry_point_contents(self):
        got = generate_entry_point_contents("sphinx.cmd.build", "main")
        want = """#!/usr/bin/env python3
import sys
from sphinx.cmd.build import main
if __name__ == "__main__":
    sys.exit(main())
"""
        self.assertEqual(got, want)

    def test_generate_entry_point_contents_with_shebang(self):
        got = generate_entry_point_contents(
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
            dependencies=["a", "b"],
            entry_points={
                "test_bin_entry": ("test_wheel.entry", "main"),
            },
        )
        MockWheel.return_value = mock_wheel_instance

        # Run the BUILD file generation code.
        extract_wheel(
            wheel_file=mock_wheel_instance.path,
            extras={},
            pip_data_exclude=[],
            enable_implicit_namespace_pkgs=True,
            repo_prefix="repo_prefix_",
            incremental=True,
            incremental_dir=self.tmpdir,
            annotation=annotation.Annotation(
                {
                    "additive_build_content": [],
                    "copy_executables": {},
                    "copy_files": {},
                    "data": ["//some/extra:data"],
                    "data_exclude_glob": ["foo/bad.data.*"],
                    "srcs_exclude_glob": ["foo/bad.srcs.*"],
                    "deps": ["//a/dep/of:some_kind"],
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
                        "//a/dep/of:some_kind",
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


if __name__ == "__main__":
    unittest.main()
