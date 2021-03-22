import unittest
import argparse
from tempfile import NamedTemporaryFile

from python.pip_install.parse_requirements_to_bzl import generate_parsed_requirements_contents
from python.pip_install.extract_wheels.lib.bazel import (
    sanitised_repo_library_label,
    whl_library_repo_prefix,
    sanitised_repo_file_label
)


class TestGenerateRequirementsFileContents(unittest.TestCase):

    def test_incremental_requirements_bzl(self) -> None:
        with NamedTemporaryFile() as requirements_lock:
            requirement_string = "foo==0.0.0"
            requirements_lock.write(bytes(requirement_string, encoding="utf-8"))
            requirements_lock.flush()
            args = argparse.Namespace()
            args.requirements_lock = requirements_lock.name
            args.repo = "pip_parsed_deps"
            contents = generate_parsed_requirements_contents(args)
            library_target = "@pip_parsed_deps_pypi__foo//:pkg"
            whl_target = "@pip_parsed_deps_pypi__foo//:whl"
            all_requirements = 'all_requirements = ["{library_target}"]'.format(library_target=library_target)
            all_whl_requirements = 'all_whl_requirements = ["{whl_target}"]'.format(whl_target=whl_target)
            self.assertIn(all_requirements, contents, contents)
            self.assertIn(all_whl_requirements, contents, contents)
            self.assertIn(requirement_string, contents, contents)


if __name__ == "__main__":
    unittest.main()
