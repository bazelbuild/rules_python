import argparse
import json
import unittest

from python.pip_install.extract_wheels.lib import arguments
from python.pip_install.parse_requirements_to_bzl import deserialize_structured_args


class ArgumentsTestCase(unittest.TestCase):
    def test_arguments(self) -> None:
        parser = argparse.ArgumentParser()
        parser = arguments.parse_common_args(parser)
        repo_name = "foo"
        index_url = "--index_url=pypi.org/simple"
        args_dict = vars(parser.parse_args(
            args=["--repo", repo_name, "--extra_pip_args={index_url}".format(index_url=json.dumps({"args": index_url}))]))
        args_dict = deserialize_structured_args(args_dict)
        self.assertIn("repo", args_dict)
        self.assertIn("extra_pip_args", args_dict)
        self.assertEqual(args_dict["pip_data_exclude"], [])
        self.assertEqual(args_dict["enable_implicit_namespace_pkgs"], False)
        self.assertEqual(args_dict["repo"], repo_name)
        self.assertEqual(args_dict["extra_pip_args"], index_url)


if __name__ == "__main__":
    unittest.main()
