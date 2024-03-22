import unittest
import zipfile
from pathlib import Path

PY310_AARCH64_BIN = "external/python_3_10_aarch64-unknown-linux-gnu/bin/python3"
PY310_X86_64_BIN = "external/python_3_10_x86_64-unknown-linux-gnu/bin/python3"
PY311_AARCH64_BIN = "external/python_3_11_aarch64-unknown-linux-gnu/bin/python3"
PY311_X86_64_BIN = "external/python_3_11_x86_64-unknown-linux-gnu/bin/python3"

def library_is_in_file_list(library_name, file_list):
    for name in file_list:
        if f"/pypi_extracted_wheel_{library_name}_" in name and name.endswith("/underlying_library"):
            return True

    return False


class ParFileTest(unittest.TestCase):

    def test_linux_py310_aarch64(self):
        file_list = Path("test/test_binary_py310_linux_aarch64.txt").read_text().splitlines()

        self.assertIn(PY310_AARCH64_BIN, file_list)
        self.assertNotIn(PY310_X86_64_BIN, file_list)
        self.assertTrue(library_is_in_file_list("pkg_a", file_list))
        self.assertTrue(library_is_in_file_list("pkg_e", file_list))
        self.assertFalse(library_is_in_file_list("pkg_f", file_list))

    def test_linux_py310_x86_64(self):
        file_list = Path("test/test_binary_py310_linux_x86_64.txt").read_text().splitlines()

        self.assertNotIn(PY310_AARCH64_BIN, file_list)
        self.assertIn(PY310_X86_64_BIN, file_list)
        self.assertTrue(library_is_in_file_list("pkg_a", file_list))
        self.assertFalse(library_is_in_file_list("pkg_e", file_list))
        self.assertFalse(library_is_in_file_list("pkg_f", file_list))

    def test_linux_py311_aarch64(self):
        file_list = Path("test/test_binary_py311_linux_aarch64.txt").read_text().splitlines()

        self.assertIn(PY311_AARCH64_BIN, file_list)
        self.assertNotIn(PY311_X86_64_BIN, file_list)
        self.assertTrue(library_is_in_file_list("pkg_a", file_list))
        self.assertTrue(library_is_in_file_list("pkg_e", file_list))
        self.assertTrue(library_is_in_file_list("pkg_f", file_list))

    def test_linux_py311_x86_64(self):
        file_list = Path("test/test_binary_py311_linux_x86_64.txt").read_text().splitlines()

        self.assertNotIn(PY311_AARCH64_BIN, file_list)
        self.assertIn(PY311_X86_64_BIN, file_list)
        self.assertTrue(library_is_in_file_list("pkg_a", file_list))
        self.assertFalse(library_is_in_file_list("pkg_e", file_list))
        self.assertTrue(library_is_in_file_list("pkg_f", file_list))

if __name__ == "__main__":
    unittest.main()
