import json
import pathlib
import unittest

from python.runfiles import runfiles


class RunTest(unittest.TestCase):
    def test_ran(self):
        rf = runfiles.Create()
        settings_path = rf.Rlocation("_main/tests/support/current_build_settings.json")
        settings = json.loads(pathlib.Path(settings_path).read_text())
        self.assertIn("runtime_env_toolchain_interpreter.sh", settings["interpreter"])


if __name__ == "__main__":
    unittest.main()
