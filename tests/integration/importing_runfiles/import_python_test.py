import unittest

class ImportingRunfilestest(unittest.TestCase):

    def test_import_python(self):
        import python
        import python.runfiles

if __name__ == "__main__":
    unittest.main()
