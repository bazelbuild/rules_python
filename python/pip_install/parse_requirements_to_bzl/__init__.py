import argparse
import json
import textwrap
import sys
import shlex
from typing import Dict, List, Optional, Tuple

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


class NamesAndRequirements:
    def __init__(self, whls: List[Tuple[str, str, Optional[str]]], aliases: List[Tuple[str, Dict[str, str]]]):
        self.whls = whls
        self.aliases = aliases


def repo_names_and_requirements(
        install_reqs: List[Tuple[InstallRequirement, str]],
        repo_prefix: str,
        platforms: Dict[str, str]) -> NamesAndRequirements:
    whls = []
    aliases = []
    for ir, line in install_reqs:
        generic_name = bazel.sanitise_name(ir.name, prefix=repo_prefix)
        if not platforms:
            whls.append((generic_name, line, None))
        else:
            select_items = {}
            for key, platform in platforms.items():
                prefix = bazel.sanitise_name(platform, prefix=repo_prefix) + "__"
                name = bazel.sanitise_name(ir.name, prefix=prefix)
                whls.append((name, line, platform))
                select_items[key] = "@{name}//:pkg".format(name=name)
            aliases.append((generic_name, select_items))
    return NamesAndRequirements(whls, aliases)


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
    # Pop these off because they won't be used as a config argument to the whl_library rule.
    requirements_lock = args.pop("requirements_lock")
    pip_platform_definitions = args.pop("pip_platform_definitions")
    repo_prefix = bazel.whl_library_repo_prefix(args["repo"])

    install_req_and_lines = parse_install_requirements(requirements_lock, args["extra_pip_args"])
    repo_names_and_reqs = repo_names_and_requirements(install_req_and_lines, repo_prefix, pip_platform_definitions)
    all_requirements = ", ".join(
        [bazel.sanitised_repo_library_label(ir.name, repo_prefix=repo_prefix) for ir, _ in install_req_and_lines]
    )
    all_whl_requirements = ", ".join(
        [bazel.sanitised_repo_file_label(ir.name, repo_prefix=repo_prefix) for ir, _ in install_req_and_lines]
    )
    return textwrap.dedent("""\
        load("@rules_python//python/pip_install:pip_repository.bzl", "whl_library", "platform_alias")

        all_requirements = [{all_requirements}]

        all_whl_requirements = [{all_whl_requirements}]

        _packages = {whl_definitions}
        _aliases = {alias_definitions}
        _config = {args}

        def _clean_name(name):
            return name.replace("-", "_").replace(".", "_").lower()

        def requirement(name):
           return "@{repo_prefix}" + _clean_name(name) + "//:pkg"

        def whl_requirement(name):
           return "@{repo_prefix}" + _clean_name(name) + "//:whl"

        def install_deps():
            for name, requirement, platform in _packages:
                whl_library(
                    name = name,
                    requirement = requirement,
                    pip_platform_definition = platform,
                    **_config,
                )
            for name, select_items in _aliases:
                platform_alias(
                    name = name,
                    select_items = select_items,
                )
        """.format(
            all_requirements=all_requirements,
            all_whl_requirements=all_whl_requirements,
            whl_definitions=repo_names_and_reqs.whls,
            alias_definitions=repo_names_and_reqs.aliases,
            args=args,
            repo_prefix=repo_prefix,
            pip_platform_definitions=pip_platform_definitions,
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
    parser.add_argument(
        "--pip_platform_definitions",
        help="A map of select keys to platform definitions in the form "
             + "<platform>-<python_version>-<implementation>-<abi>",
    )
    arguments.parse_common_args(parser)
    args = parser.parse_args()

    with open("requirements.bzl", "w") as requirement_file:
        requirement_file.write(
            generate_parsed_requirements_contents(args)
        )
