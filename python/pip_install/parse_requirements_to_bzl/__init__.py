import argparse
import json
import textwrap
import sys
import shlex
from typing import List, Tuple

from python.pip_install.extract_wheels.lib import bazel, arguments
from pip._internal.req import parse_requirements, constructors
from pip._internal.req.req_install import InstallRequirement
from pip._internal.req.req_file import get_file_content, preprocess, handle_line, get_line_parser, RequirementsFileParser
from pip._internal.network.session import PipSession


def parse_install_requirements(requirements_lock: str, extra_pip_args: List[str]) -> List[Tuple[InstallRequirement, str]]:
    ps = PipSession()
    # This is roughly taken from pip._internal.req.req_file.parse_requirements
    # (https://github.com/pypa/pip/blob/21.0.1/src/pip/_internal/req/req_file.py#L127) in order to keep
    # the original line (sort-of, its preprocessed) from the requirements_lock file around, to pass to sub repos
    # as the requirement.
    line_parser = get_line_parser(finder=None)
    parser = RequirementsFileParser(ps, line_parser)
    install_req_and_lines: List[Tuple[InstallRequirement, str]] = []
    _, content = get_file_content(requirements_lock, ps)
    for parsed_line, (_, line) in zip(parser.parse(requirements_lock, constraint=False), preprocess(content)):
        if parsed_line.is_requirement:
            install_req_and_lines.append(
                (
                    constructors.install_req_from_line(parsed_line.requirement),
                    line
                )
            )

        else:
            extra_pip_args.extend(shlex.split(line))
    return install_req_and_lines


def repo_names_and_requirements(install_reqs: List[Tuple[InstallRequirement, str]], repo_prefix: str) -> List[Tuple[str, str]]:
    return [
        (
            bazel.sanitise_name(ir.name, prefix=repo_prefix),
            line,
        )
        for ir, line in install_reqs
    ]


def generate_parsed_requirements_contents(all_args: argparse.Namespace) -> str:
    """
    Parse each requirement from the requirements_lock file, and prepare arguments for each
    repository rule, which will represent the individual requirements.

    Generates a requirements.bzl file containing a macro (install_deps()) which instantiates
    a repository rule for each requirment in the lock file.
    """

    args = dict(vars(all_args))
    args = arguments.deserialize_structured_args(args)
    args.setdefault("python_interpreter", sys.executable)
    # Pop this off because it wont be used as a config argument to the whl_library rule.
    requirements_lock = args.pop("requirements_lock")
    repo_prefix = bazel.whl_library_repo_prefix(args["repo"])

    install_req_and_lines = parse_install_requirements(requirements_lock, args["extra_pip_args"])
    repo_names_and_reqs = repo_names_and_requirements(install_req_and_lines, repo_prefix)
    all_requirements = ", ".join(
        [bazel.sanitised_repo_library_label(ir.name, repo_prefix=repo_prefix) for ir, _ in install_req_and_lines]
    )
    all_whl_requirements = ", ".join(
        [bazel.sanitised_repo_file_label(ir.name, repo_prefix=repo_prefix) for ir, _ in install_req_and_lines]
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
           return "@{repo_prefix}" + _clean_name(name) + "//:{py_library_label}"

        def whl_requirement(name):
           return "@{repo_prefix}" + _clean_name(name) + "//:{wheel_file_label}"

        def data_requirement(name):
            return "@{repo_prefix}" + _clean_name(name) + "//:{data_label}"

        def dist_info_requirement(name):
            return "@{repo_prefix}" + _clean_name(name) + "//:{dist_info_label}"

        def entry_point(pkg, script = None):
            if not script:
                script = pkg
            return "@{repo_prefix}" + _clean_name(pkg) + "//:{entry_point_prefix}_" + script

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
            py_library_label=bazel.PY_LIBRARY_LABEL,
            wheel_file_label=bazel.WHEEL_FILE_LABEL,
            data_label=bazel.DATA_LABEL,
            dist_info_label=bazel.DIST_INFO_LABEL,
            entry_point_prefix=bazel.WHEEL_ENTRY_POINT_PREFIX,
            )
        )

def coerce_to_bool(option):
    return str(option).lower() == 'true'

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
        "--python_interpreter",
        help="The python interpreter that will be used to download and unpack the wheels.",
    )
    parser.add_argument(
        "--python_interpreter_target",
        help="Bazel target of a python interpreter.\
It will be used in repository rules so it must be an already built interpreter.\
If set, it will take precedence over python_interpreter.",
    )
    parser.add_argument(
        "--quiet",
        type=coerce_to_bool,
        default=True,
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
