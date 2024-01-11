import unittest

class ImportingRunfilestest(unittest.TestCase):
    def test_import_both(self):
        import rules_python
        import rules_python.python
        import python
        self.assertIs(rules_python.python, python)

        import rules_python.python.runfiles
        import python.runfiles
        self.assertIs(rules_python.python.runfiles, python.runfiles)

        import rules_python.python.runfiles.runfiles
        import python.runfiles.runfiles
        self.assertIs(rules_python.python.runfiles.runfiles, python.runfiles.runfiles)


if __name__ == "__main__":
    unittest.main()
