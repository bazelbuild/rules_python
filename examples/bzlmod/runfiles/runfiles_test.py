import os
import unittest

from other_module.pkg import lib

from python.runfiles import runfiles


class RunfilesTest(unittest.TestCase):
    # """Unit tests for `runfiles.Runfiles`."""
    def testCurrentRepository(self):
        self.assertEqual(runfiles.Create().CurrentRepository(), "")

    def testRunfilesWithRepoMapping(self):
        data_path = runfiles.Create().Rlocation("example_bzlmod/runfiles/data/data.txt")
        with open(data_path) as f:
            self.assertEqual(f.read().strip(), "Hello, example_bzlmod!")

    def testRunfileWithRlocationpath(self):
        data_rlocationpath = os.getenv("DATA_RLOCATIONPATH")
        data_path = runfiles.Create().Rlocation(data_rlocationpath)
        with open(data_path) as f:
            self.assertEqual(f.read().strip(), "Hello, example_bzlmod!")

    def testRunfileInOtherModuleWithOurRepoMapping(self):
        data_path = runfiles.Create().Rlocation(
            "our_other_module/other_module/pkg/data/data.txt"
        )
        with open(data_path) as f:
            self.assertEqual(f.read().strip(), "Hello, other_module!")

    def testRunfileInOtherModuleWithItsRepoMapping(self):
        data_path = lib.GetRunfilePathWithRepoMapping()
        with open(data_path) as f:
            self.assertEqual(f.read().strip(), "Hello, other_module!")

    def testRunfileInOtherModuleWithCurrentRepository(self):
        data_path = lib.GetRunfilePathWithCurrentRepository()
        with open(data_path) as f:
            self.assertEqual(f.read().strip(), "Hello, other_module!")

    def testRunfileInOtherModuleWithRlocationpath(self):
        data_rlocationpath = os.getenv("OTHER_MODULE_DATA_RLOCATIONPATH")
        data_path = runfiles.Create().Rlocation(data_rlocationpath)
        with open(data_path) as f:
            self.assertEqual(f.read().strip(), "Hello, other_module!")


if __name__ == "__main__":
    unittest.main()
