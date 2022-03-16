"""Main entry point."""
import os
import sys

from python.pip_install.parse_requirements_to_bzl import main

if __name__ == "__main__":
    # Under `bazel run`, just print the generated starlark code.
    # This allows users to check that into their repository rather than
    # call pip_parse to generate as a repository rule.
    if "BUILD_WORKING_DIRECTORY" in os.environ:
        os.chdir(os.environ["BUILD_WORKING_DIRECTORY"])
        main(sys.stdout)
    else:
        with open("requirements.bzl", "w") as requirement_file:
            main(requirement_file)
