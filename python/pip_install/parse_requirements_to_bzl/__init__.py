import argparse
import json
import re
import textwrap
import shlex
import sys
from typing import List, Tuple

from python.pip_install.extract_wheels.lib import bazel, arguments
from pip._internal.req import parse_requirements, constructors
from pip._internal.req.req_install import InstallRequirement
from pip._internal.network.session import PipSession


def parse_install_requirements(requirements_lock: str) -> List[InstallRequirement]:
    return [
        constructors.install_req_from_parsed_requirement(pr)
        for pr in parse_requirements(requirements_lock, session=PipSession())
    ]


def repo_names_and_requirements(install_reqs: List[InstallRequirement], repo_prefix: str) -> List[Tuple[str, str]]:
    return [
        (
            bazel.sanitise_name(ir.name, prefix=repo_prefix),
            str(ir.req)
        )
        for ir in install_reqs
    ]

def deserialize_structured_args(args):
    """Deserialize structured arguments passed from the starlark rules.
        Args:
            args: dict of parsed command line arguments
    """
    structured_args = ("extra_pip_args", "pip_data_exclude")
    for arg_name in structured_args:
        if args.get(arg_name) is not None:
            args[arg_name] = json.loads(args[arg_name])["args"]
    return args


def read_embedded_pip_args(args):
    """Augment extra_pip_args from directives in requirements_lock file
        Args:
            args: deserialized args to read and modify
    """
    extra_pip_args = args.get("extra_pip_args")
    requirements_lock = args["requirements_lock"]
    with open(requirements_lock) as f:
        embedded = [
            line for line in f.readlines()
            if line.strip().startswith('-')
        ]

    embedded = [
        arg for args in embedded
        for arg in shlex.split(args, comments=True)
    ]
    if embedded:
        args["extra_pip_args"] = embedded + (extra_pip_args or [])


def generate_parsed_requirements_contents(all_args: argparse.Namespace) -> str:
    """
    Parse each requirement from the requirements_lock file, and prepare arguments for each
    repository rule, which will represent the individual requirements.

    Generates a requirements.bzl file containing a macro (install_deps()) which instantiates
    a repository rule for each requirment in the lock file.
    """

    args = dict(vars(all_args))
    args = deserialize_structured_args(args)
    args.setdefault("python_interpreter", sys.executable)
    read_embedded_pip_args(args)
    # Pop this off because it wont be used as a config argument to the whl_library rule.
    requirements_lock = args.pop("requirements_lock")
    repo_prefix = bazel.whl_library_repo_prefix(args["repo"])

    install_reqs = parse_install_requirements(requirements_lock)
    repo_names_and_reqs = repo_names_and_requirements(install_reqs, repo_prefix)
    all_requirements = ", ".join(
        [bazel.sanitised_repo_library_label(ir.name, repo_prefix=repo_prefix) for ir in install_reqs]
    )
    all_whl_requirements = ", ".join(
        [bazel.sanitised_repo_file_label(ir.name, repo_prefix=repo_prefix) for ir in install_reqs]
    )
    return textwrap.dedent("""\
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
        """.format(
            all_requirements=all_requirements,
            all_whl_requirements=all_whl_requirements,
            repo_names_and_reqs=repo_names_and_reqs,
            args=args,
            repo_prefix=repo_prefix,
            )
        )


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
    arguments.parse_common_args(parser)
    args = parser.parse_args()

    with open("requirements.bzl", "w") as requirement_file:
        requirement_file.write(
            generate_parsed_requirements_contents(args)
        )
