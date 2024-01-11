import unittest
import sys
import types
import importlib
import importlib.util
import importlib.machinery
import os.path
import pathlib

class FakeRulesPython(types.ModuleType):
    def __init__(self, *, repo_root):
        super().__init__(name="rules_python")
        self.__file__ = f"fake @rules_python module"
        self._repo_root = repo_root

        spec = importlib.machinery.ModuleSpec(
            name=self.__name__,
            loader=None,
        )
        spec.submodule_search_locations = [repo_root]
        mod = importlib.util.module_from_spec(spec)
        self._mod = mod

    def __getattr__(self, item):
        """Dispatches the getattr to the real module."""
        #print("==getattr: ", item)
        v = getattr(self._mod, item)
        #print("==getattr: ", item, "->", v)
        return v

class ImportingRunfilestest(unittest.TestCase):
    def test_import_rules_python(self):
        assert "rules_python" not in sys.modules

        import rules_python as real_rules_python
        import rules_python.python.runfiles.runfiles
        rf = rules_python.python.runfiles.runfiles.Create()
        runfiles_root = rf._python_runfiles_root

        # With bzlmod, the ('', 'rules_python') entry is present (maps
        # the current repo's concept of "rules_python" to its runfiles name.
        # Without bzlmod, the entry isn't present, so no mapping is needed,
        # and we can just use plain rules_python.
        rules_python_dirname = rf._repo_mapping.get(('', 'rules_python'), 'rules_python')
        repo_root = os.path.join(runfiles_root, rules_python_dirname)

        # Clear out all the imports from using the runfiles
        for name in list(sys.modules.keys()):
            if name == "rules_python" or name.startswith("rules_python."):
                del sys.modules[name]
        importlib.invalidate_caches()

        fake_rules_python = FakeRulesPython(repo_root=str(repo_root))
        sys.modules["rules_python"] = fake_rules_python

        import rules_python

        self.assertIsNot(rules_python, real_rules_python)

        import rules_python.python
        import rules_python.python.runfiles
        import rules_python.python.runfiles.runfiles

        import python
        import python.runfiles
        import python.runfiles.runfiles

        self.assertIs(rules_python.python, python)
        self.assertIs(rules_python.python.runfiles, python.runfiles)
        self.assertIs(rules_python.python.runfiles.runfiles, python.runfiles.runfiles)


if __name__ == "__main__":
    unittest.main()

