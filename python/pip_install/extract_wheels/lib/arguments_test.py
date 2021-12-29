import argparse
import json
import unittest

from python.pip_install.extract_wheels.lib import arguments


class ArgumentsTestCase(unittest.TestCase):
    def test_arguments(self) -> None:
        parser = argparse.ArgumentParser()
        parser = arguments.parse_common_args(parser)
        repo_name = "foo"
        repo_prefix = "pypi_"
        index_url = "--index_url=pypi.org/simple"
        extra_pip_args = [index_url]
        args_dict = vars(
            parser.parse_args(
                args=[
                    "--repo",
                    repo_name,
                    f"--extra_pip_args={json.dumps({'arg': extra_pip_args})}",
                    "--repo-prefix",
                    repo_prefix,
                ]
            )
        )
        args_dict = arguments.deserialize_structured_args(args_dict)
        self.assertIn("repo", args_dict)
        self.assertIn("extra_pip_args", args_dict)
        self.assertEqual(args_dict["pip_data_exclude"], [])
        self.assertEqual(args_dict["enable_implicit_namespace_pkgs"], False)
        self.assertEqual(args_dict["repo"], repo_name)
        self.assertEqual(args_dict["repo_prefix"], repo_prefix)
        self.assertEqual(args_dict["extra_pip_args"], extra_pip_args)

    def test_deserialize_structured_args(self) -> None:
        serialized_args = {
            "pip_data_exclude": json.dumps({"arg": ["**.foo"]}),
            "environment": json.dumps({"arg": {"PIP_DO_SOMETHING": "True"}}),
        }
        args = arguments.deserialize_structured_args(serialized_args)
        self.assertEqual(args["pip_data_exclude"], ["**.foo"])
        self.assertEqual(args["environment"], {"PIP_DO_SOMETHING": "True"})
        self.assertEqual(args["extra_pip_args"], [])


if __name__ == "__main__":
    unittest.main()
