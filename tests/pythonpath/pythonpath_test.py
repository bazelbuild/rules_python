import os
import unittest

class PythonPathTest(unittest.TestCase):

    def test_environment(self):
        """Validates that PYTHONPATH is empty."""
        self.assertFalse(os.environ["PYTHONPATH"])

if __name__ == "__main__":
    unittest.main()
