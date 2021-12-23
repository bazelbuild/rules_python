import os
import unittest
from contextlib import contextmanager
from pathlib import Path
from tempfile import TemporaryDirectory

from python.pip_install.extract_wheels.lib import purelib


class TestPurelibTestCase(unittest.TestCase):
    @contextmanager
    def setup_faux_unzipped_wheel(self):
        files = [
            ("faux_wheel.data/purelib/toplevel/foo.py", "# foo"),
            ("faux_wheel.data/purelib/toplevel/dont_overwrite.py", "overwritten"),
            ("faux_wheel.data/purelib/toplevel/subdir/baz.py", "overwritten"),
            ("toplevel/bar.py", "# bar"),
            ("toplevel/dont_overwrite.py", "original"),
        ]
        with TemporaryDirectory() as td:
            self.td_path = Path(td)
            self.purelib_path = self.td_path / Path("faux_wheel.data/purelib")
            for file_, content in files:
                path = self.td_path / Path(file_)
                path.parent.mkdir(parents=True, exist_ok=True)
                with open(str(path), "w") as f:
                    f.write(content)
            yield

    def test_spread_purelib_(self):
        with self.setup_faux_unzipped_wheel():
            purelib._spread_purelib(self.purelib_path, self.td_path)
            self.assertTrue(Path(self.td_path, "toplevel/foo.py").exists())
            self.assertTrue(Path(self.td_path, "toplevel/subdir/baz.py").exists())
            with open(Path(self.td_path, "toplevel/dont_overwrite.py")) as original:
                self.assertEqual(original.read().strip(), "original")


if __name__ == "__main__":
    unittest.main()
