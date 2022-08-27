import unittest

from python.pip_install.extract_wheels import bazel


class TestGenerateRequirementsFileContents(unittest.TestCase):
    def test_all_wheel_requirements(self) -> None:
        contents = bazel.generate_requirements_file_contents(
            repo_name="test",
            targets=['"@test//pypi__pkg1"', '"@test//pypi__pkg2"'],
        )
        expected = (
            'all_whl_requirements = ["@test//pypi__pkg1:whl","@test//pypi__pkg2:whl"]'
        )
        self.assertIn(expected, contents)


if __name__ == "__main__":
    unittest.main()
