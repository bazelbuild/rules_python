import tempfile
import unittest
from pathlib import Path

from python.private.whl_filegroup import extract_wheel_files

_WHEEL = Path("examples/wheel/example_minimal_package-0.0.1-py3-none-any.whl")


class WheelRecordTest(unittest.TestCase):
    def test_get_wheel_record(self) -> None:
        record = extract_wheel_files.get_record(_WHEEL)
        expected = {
            "examples/wheel/lib/data.txt": (
                "sha256=9vJKEdfLu8bZRArKLroPZJh1XKkK3qFMXiM79MBL2Sg",
                12,
            ),
            "examples/wheel/lib/module_with_data.py": (
                "sha256=8s0Khhcqz3yVsBKv2IB5u4l4TMKh7-c_V6p65WVHPms",
                637,
            ),
            "examples/wheel/lib/simple_module.py": (
                "sha256=z2hwciab_XPNIBNH8B1Q5fYgnJvQTeYf0ZQJpY8yLLY",
                637,
            ),
            "examples/wheel/main.py": (
                "sha256=sgg5iWN_9inYBjm6_Zw27hYdmo-l24fA-2rfphT-IlY",
                909,
            ),
            "example_minimal_package-0.0.1.dist-info/WHEEL": (
                "sha256=sobxWSyDDkdg_rinUth-jxhXHqoNqlmNMJY3aTZn2Us",
                91,
            ),
            "example_minimal_package-0.0.1.dist-info/METADATA": (
                "sha256=cfiQ2hFJhCKCUgbwtAwWG0fhW6NTzw4cr1uKOBcV_IM",
                76,
            ),
        }
        self.maxDiff = None
        self.assertDictEqual(record, expected)

    def test_get_files(self) -> None:
        pattern = "(examples/wheel/lib/.*\.txt$|.*main)"
        record = extract_wheel_files.get_record(_WHEEL)
        files = extract_wheel_files.get_files(record, pattern)
        expected = ["examples/wheel/lib/data.txt", "examples/wheel/main.py"]
        self.assertEqual(files, expected)

    def test_extract(self) -> None:
        files = {"examples/wheel/lib/data.txt", "examples/wheel/main.py"}
        with tempfile.TemporaryDirectory() as tmpdir:
            outdir = Path(tmpdir)
            extract_wheel_files.extract_files(_WHEEL, files, outdir)
            extracted_files = {
                f.relative_to(outdir).as_posix()
                for f in outdir.glob("**/*")
                if f.is_file()
            }
        self.assertEqual(extracted_files, files)


if __name__ == "__main__":
    unittest.main()
