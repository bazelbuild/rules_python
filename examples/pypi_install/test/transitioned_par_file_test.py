import unittest
import zipfile
from pathlib import Path

AARCH64_BIN = "external/python39_aarch64-unknown-linux-gnu/bin/python3"
X86_BIN = "external/python39_x86_64-unknown-linux-gnu/bin/python3"

def library_is_in_file_list(library_name, file_list):
    for name in file_list:
        if f"/pypi_extracted_wheel_{library_name}_" in name and name.endswith("/underlying_library"):
            return True

    return False


class ParFileTest(unittest.TestCase):

    def test_linux_aarch64(self):
        file_list = Path("test/test_binary_linux_aarch64.txt").read_text().splitlines()

        self.assertIn(AARCH64_BIN, file_list)
        self.assertNotIn(X86_BIN, file_list)
        self.assertTrue(library_is_in_file_list("pkg_a", file_list))
        self.assertTrue(library_is_in_file_list("pkg_e", file_list))

    def test_linux_x86(self):
        file_list = Path("test/test_binary_linux_x86.txt").read_text().splitlines()

        self.assertNotIn(AARCH64_BIN, file_list)
        self.assertIn(X86_BIN, file_list)
        self.assertTrue(library_is_in_file_list("pkg_a", file_list))
        self.assertFalse(library_is_in_file_list("pkg_e", file_list))

if __name__ == "__main__":
    unittest.main()
