import unittest
from pathlib import Path

from python.pip_install.tools.wheel_installer import get_wheel_records, wheel

_WHEEL = wheel.Wheel(
    Path("examples/wheel/example_minimal_package-0.0.1-py3-none-any.whl")
)


class WheelRecordTest(unittest.TestCase):
    def test_get_wheel_record(self) -> None:
        record = _WHEEL.record
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
        files = get_wheel_records.get_files(_WHEEL, pattern)
        expected = ["examples/wheel/lib/data.txt", "examples/wheel/main.py"]
        self.assertEqual(files, expected)


if __name__ == "__main__":
    unittest.main()
