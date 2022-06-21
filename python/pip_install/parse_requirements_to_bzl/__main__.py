"""Main entry point."""
import os
import sys

from python.pip_install.parse_requirements_to_bzl import main

if __name__ == "__main__":
    with open("requirements.bzl", "w") as requirement_file:
        main(requirement_file)
