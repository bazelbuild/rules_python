import argparse
import textwrap
import sys

from python.pip_install.extract_wheels.lib import bazel, utilities
from pip._internal.req import parse_requirements, constructors
from pip._internal.network.session import PipSession


def parse_install_requirements(requirements_lock):
    return [
        constructors.install_req_from_parsed_requirement(pr)
        for pr in parse_requirements(requirements_lock, session=PipSession())
    ]


def repo_names_and_requirements(install_reqs, repo_prefix):
    return [
        (
            bazel.sanitise_name(ir.name, prefix=repo_prefix),
            str(ir.req)
        )
        for ir in install_reqs
    ]


def generate_incremental_requirements_contents(all_args) -> str:
    """
    Parse each requirement from the requirements_lock file, and prepare arguments for each
    repository rule, which will represent the individual requirements.

    Generates a requirements.bzl file containing a macro (install_deps()) which instantiates
    a repository rule for each requirment in the lock file.
    """

    args = dict(all_args.__dict__)
    args.setdefault("python_interpreter", sys.executable)
    # Pop this off because it wont be used as a config argurment to thw whl_library rule.
    requirements_lock = args.pop("requirements_lock")
    repo_prefix = bazel.create_incremental_repo_prefix(args["repo"])

    install_reqs = parse_install_requirements(requirements_lock)
    repo_names_and_reqs = repo_names_and_requirements(install_reqs, repo_prefix)
    all_requirements = ", ".join(
        [bazel.sanitised_repo_library_label(ir.name, repo_prefix=repo_prefix) for ir in install_reqs]
    )
    all_whl_requirements = ", ".join(
        [bazel.sanitised_repo_file_label(ir.name, repo_prefix=repo_prefix) for ir in install_reqs]
    )
    return textwrap.dedent(f"""\
        load("@rules_python//python/pip_install:pip_repository.bzl", "whl_library")

        all_requirements = [{all_requirements}]

        all_whl_requirements = [{all_whl_requirements}]

        _packages = {repo_names_and_reqs}
        _config = {args}

        def _clean_name(name):
            return name.replace("-", "_").replace(".", "_").lower()

        def requirement(name):
           return "@{repo_prefix}" + _clean_name(name) + "//:pkg"

        def whl_requirement(name):
           return "@{repo_prefix}" + _clean_name(name) + "//:whl"

        def install_deps():
            for name, requirement in _packages:
                whl_library(
                    name = name,
                    requirement = requirement,
                    **_config,
                )
""")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create rules to incrementally fetch needed \
dependencies from a fully resolved requirements lock file."
    )
    parser.add_argument(
        "--requirements_lock",
        action="store",
        required=True,
        help="Path to fully resolved requirements.txt to use as the source of repos.",
    )
    parser.add_argument(
        "--quiet",
        type=bool,
        action="store",
        required=True,
        help="Whether to print stdout / stderr from child repos.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        action="store",
        required=True,
        help="timeout to use for pip operation.",
    )
    utilities.parse_common_args(parser)
    args = parser.parse_args()

    with open("requirements.bzl", "w") as requirement_file:
        requirement_file.write(
            generate_incremental_requirements_contents(args)
        )
