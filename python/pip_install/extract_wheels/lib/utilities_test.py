import unittest
import argparse

from python.pip_install.extract_wheels.lib import utilities


class TestUtilities(unittest.TestCase):
    def test_utilities(self) -> None:
        parser = argparse.ArgumentParser()
        parser = utilities.parse_common_args(parser)
        repo_name = "foo"
        index_url = "--index_url=pypi.org/simple"
        args_dict = vars(parser.parse_args(args=["--repo", repo_name, f"--extra_pip_args={index_url}"]))
        self.assertIn("repo", args_dict)
        self.assertIn("extra_pip_args", args_dict)
        self.assertEqual(args_dict["pip_data_exclude"], None)
        self.assertEqual(args_dict["enable_implicit_namespace_pkgs"], False)
        self.assertEqual(args_dict["repo"], repo_name)
        self.assertEqual(args_dict["extra_pip_args"], index_url)


if __name__ == "__main__":
    unittest.main()
