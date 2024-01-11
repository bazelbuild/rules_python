import unittest
import sys, pathlib

for x in sys.path:
    print(x)
class ImportingRunfilestest(unittest.TestCase):
    def test_import_rules_python(self):
        import rules_python
        import pdb; pdb.set_trace()
        # so the problem is that, in a workspace build,
        # the runfiles directory comes first. This means
        # import rules_python hits the top-level init file.
        # Which is a problem, because we don't have a way to import from
        # the sub-directory and replace ourselves
        import rules_python.python
        import rules_python.python.runfiles
        import rules_python.python.runfiles.runfiles

if __name__ == "__main__":
    unittest.main()
