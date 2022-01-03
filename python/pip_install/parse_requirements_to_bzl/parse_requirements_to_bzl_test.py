import argparse
import json
import tempfile
import unittest
from pathlib import Path

from python.pip_install.parse_requirements_to_bzl import (
    generate_parsed_requirements_contents,
)


class TestParseRequirementsToBzl(unittest.TestCase):
    def test_generated_requirements_bzl(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            requirements_lock = Path(temp_dir) / "requirements.txt"
            comments_and_flags = "#comment\n--require-hashes True\n"
            requirement_string = "foo==0.0.0 --hash=sha256:hashofFoowhl"
            requirements_lock.write_bytes(
                bytes(comments_and_flags + requirement_string, encoding="utf-8")
            )
            args = argparse.Namespace()
            args.requirements_lock = str(requirements_lock.resolve())
            args.repo_prefix = "pip_parsed_deps_pypi__"
            extra_pip_args = ["--index-url=pypi.org/simple"]
            pip_data_exclude = ["**.foo"]
            args.extra_pip_args = json.dumps({"arg": extra_pip_args})
            args.pip_data_exclude = json.dumps({"arg": pip_data_exclude})
            args.python_interpreter = "/custom/python3"
            args.python_interpreter_target = "@custom_python//:exec"
            args.environment = json.dumps({"arg": {}})
            contents = generate_parsed_requirements_contents(args)
            library_target = "@pip_parsed_deps_pypi__foo//:pkg"
            whl_target = "@pip_parsed_deps_pypi__foo//:whl"
            all_requirements = 'all_requirements = ["{library_target}"]'.format(
                library_target=library_target
            )
            all_whl_requirements = 'all_whl_requirements = ["{whl_target}"]'.format(
                whl_target=whl_target
            )
            self.assertIn(all_requirements, contents, contents)
            self.assertIn(all_whl_requirements, contents, contents)
            self.assertIn(requirement_string, contents, contents)
            all_flags = extra_pip_args + ["--require-hashes", "True"]
            self.assertIn(
                "'extra_pip_args': {}".format(repr(all_flags)), contents, contents
            )
            self.assertIn(
                "'pip_data_exclude': {}".format(repr(pip_data_exclude)),
                contents,
                contents,
            )
            self.assertIn("'python_interpreter': '/custom/python3'", contents, contents)
            self.assertIn(
                "'python_interpreter_target': '@custom_python//:exec'",
                contents,
                contents,
            )
            # Assert it gets set to an empty dict by default.
            self.assertIn("'environment': {}", contents, contents)


if __name__ == "__main__":
    unittest.main()
