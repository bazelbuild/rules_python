import pathlib
import shutil
import tempfile
from typing import Optional
import unittest

from python.pip_install.extract_wheels.lib import namespace_pkgs


class TempDir:
    def __init__(self) -> None:
        self.dir = tempfile.mkdtemp()

    def root(self) -> str:
        return self.dir

    def add_dir(self, rel_path: str) -> None:
        d = pathlib.Path(self.dir, rel_path)
        d.mkdir(parents=True)

    def add_file(self, rel_path: str, contents: Optional[str] = None) -> None:
        f = pathlib.Path(self.dir, rel_path)
        f.parent.mkdir(parents=True, exist_ok=True)
        if contents:
            with open(str(f), "w") as writeable_f:
                writeable_f.write(contents)
        else:
            f.touch()

    def remove(self) -> None:
        shutil.rmtree(self.dir)


class TestImplicitNamespacePackages(unittest.TestCase):
    def test_finds_correct_namespace_packages(self) -> None:
        directory = TempDir()
        directory.add_file("foo/bar/biz.py")
        directory.add_file("foo/bee/boo.py")
        directory.add_file("foo/buu/__init__.py")
        directory.add_file("foo/buu/bii.py")

        expected = {
            directory.root() + "/foo",
            directory.root() + "/foo/bar",
            directory.root() + "/foo/bee",
        }
        actual = namespace_pkgs.implicit_namespace_packages(directory.root())
        self.assertEqual(actual, expected)

    def test_ignores_empty_directories(self) -> None:
        directory = TempDir()
        directory.add_file("foo/bar/biz.py")
        directory.add_dir("foo/cat")

        expected = {
            directory.root() + "/foo",
            directory.root() + "/foo/bar",
        }
        actual = namespace_pkgs.implicit_namespace_packages(directory.root())
        self.assertEqual(actual, expected)

    def test_empty_case(self) -> None:
        directory = TempDir()
        directory.add_file("foo/__init__.py")
        directory.add_file("foo/bar/__init__.py")
        directory.add_file("foo/bar/biz.py")

        actual = namespace_pkgs.implicit_namespace_packages(directory.root())
        self.assertEqual(actual, set())


if __name__ == "__main__":
    unittest.main()
