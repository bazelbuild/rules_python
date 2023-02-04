# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import json
import tempfile
import unittest
from pathlib import Path
from textwrap import dedent

from pip._internal.req.req_install import InstallRequirement

from python.pip_install.tools.lock_file_generator import lock_file_generator


class TestParseRequirementsToBzl(unittest.TestCase):
    maxDiff = None

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
            args.repo = ("pip_parsed_deps_pypi__",)
            args.repo_prefix = "pip_parsed_deps_pypi__"
            extra_pip_args = ["--index-url=pypi.org/simple"]
            pip_data_exclude = ["**.foo"]
            args.extra_pip_args = json.dumps({"arg": extra_pip_args})
            args.pip_data_exclude = json.dumps({"arg": pip_data_exclude})
            args.python_interpreter = "/custom/python3"
            args.python_interpreter_target = "@custom_python//:exec"
            args.environment = json.dumps({"arg": {}})
            whl_library_args = lock_file_generator.parse_whl_library_args(args)
            contents = lock_file_generator.generate_parsed_requirements_contents(
                requirements_lock=args.requirements_lock,
                repo=args.repo,
                repo_prefix=args.repo_prefix,
                whl_library_args=whl_library_args,
            )
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

    def test_parse_install_requirements_with_args(self):
        # Test requirements files with varying arguments
        for requirement_args in ("", "--index-url https://index.python.com"):
            with tempfile.TemporaryDirectory() as temp_dir:
                requirements_lock = Path(temp_dir) / "requirements.txt"
                requirements_lock.write_text(
                    dedent(
                        """\
                    {}

                    wheel==0.37.1 \\
                        --hash=sha256:4bdcd7d840138086126cd09254dc6195fb4fc6f01c050a1d7236f2630db1d22a \\
                        --hash=sha256:e9a504e793efbca1b8e0e9cb979a249cf4a0a7b5b8c9e8b65a5e39d49529c1c4
                        # via -r requirements.in
                    setuptools==58.2.0 \\
                        --hash=sha256:2551203ae6955b9876741a26ab3e767bb3242dafe86a32a749ea0d78b6792f11 \
                        --hash=sha256:2c55bdb85d5bb460bd2e3b12052b677879cffcf46c0c688f2e5bf51d36001145
                        # via -r requirements.in
                    """.format(
                            requirement_args
                        )
                    )
                )

                install_req_and_lines = lock_file_generator.parse_install_requirements(
                    str(requirements_lock), ["-v"]
                )

                # There should only be two entries for the two requirements
                self.assertEqual(len(install_req_and_lines), 2)

                # The first index in each tuple is expected to be an `InstallRequirement` object
                self.assertIsInstance(install_req_and_lines[0][0], InstallRequirement)
                self.assertIsInstance(install_req_and_lines[1][0], InstallRequirement)

                # Ensure the requirements text is correctly parsed with the trailing arguments
                self.assertTupleEqual(
                    install_req_and_lines[0][1:],
                    (
                        "wheel==0.37.1     --hash=sha256:4bdcd7d840138086126cd09254dc6195fb4fc6f01c050a1d7236f2630db1d22a     --hash=sha256:e9a504e793efbca1b8e0e9cb979a249cf4a0a7b5b8c9e8b65a5e39d49529c1c4",
                    ),
                )
                self.assertTupleEqual(
                    install_req_and_lines[1][1:],
                    (
                        "setuptools==58.2.0     --hash=sha256:2551203ae6955b9876741a26ab3e767bb3242dafe86a32a749ea0d78b6792f11                         --hash=sha256:2c55bdb85d5bb460bd2e3b12052b677879cffcf46c0c688f2e5bf51d36001145",
                    ),
                )

    def test_parse_install_requirements_pinned_direct_reference(self):
        # Test PEP-440 direct references
        with tempfile.TemporaryDirectory() as temp_dir:
            requirements_lock = Path(temp_dir) / "requirements.txt"
            requirements_lock.write_text(
                dedent(
                    """\
                onnx @ https://files.pythonhosted.org/packages/24/93/f5b001dc0f5de84ce049a34ff382032cd9478e1080aa6ac48470fa810577/onnx-1.11.0-cp39-cp39-manylinux_2_12_x86_64.manylinux2010_x86_64.whl \
                    --hash=sha256:67c6d2654c1c203e5c839a47900b51f588fd0de71bbd497fb193d30a0b3ec1e9
                """
                )
            )

            install_req_and_lines = lock_file_generator.parse_install_requirements(
                str(requirements_lock), ["-v"]
            )

            self.assertEqual(len(install_req_and_lines), 1)
            self.assertEqual(install_req_and_lines[0][0].name, "onnx")

            self.assertTupleEqual(
                install_req_and_lines[0][1:],
                (
                    "onnx @ https://files.pythonhosted.org/packages/24/93/f5b001dc0f5de84ce049a34ff382032cd9478e1080aa6ac48470fa810577/onnx-1.11.0-cp39-cp39-manylinux_2_12_x86_64.manylinux2010_x86_64.whl                     --hash=sha256:67c6d2654c1c203e5c839a47900b51f588fd0de71bbd497fb193d30a0b3ec1e9",
                ),
            )


if __name__ == "__main__":
    unittest.main()
