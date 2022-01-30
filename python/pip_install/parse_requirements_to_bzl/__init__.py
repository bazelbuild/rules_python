import argparse
import json
import shlex
import sys
import textwrap
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from pip._internal.network.session import PipSession
from pip._internal.req import constructors
from pip._internal.req.req_file import (
    RequirementsFileParser,
    get_file_content,
    get_line_parser,
    preprocess,
)
from pip._internal.req.req_install import InstallRequirement

from python.pip_install.extract_wheels.lib import annotation, arguments, bazel


def parse_install_requirements(
    requirements_lock: str, extra_pip_args: List[str]
) -> List[Tuple[InstallRequirement, str]]:
    ps = PipSession()
    # This is roughly taken from pip._internal.req.req_file.parse_requirements
    # (https://github.com/pypa/pip/blob/21.0.1/src/pip/_internal/req/req_file.py#L127) in order to keep
    # the original line (sort-of, its preprocessed) from the requirements_lock file around, to pass to sub repos
    # as the requirement.
    line_parser = get_line_parser(finder=None)
    parser = RequirementsFileParser(ps, line_parser)
    install_req_and_lines: List[Tuple[InstallRequirement, str]] = []
    _, content = get_file_content(requirements_lock, ps)
    for parsed_line, (_, line) in zip(
        parser.parse(requirements_lock, constraint=False), preprocess(content)
    ):
        if parsed_line.is_requirement:
            install_req_and_lines.append(
                (constructors.install_req_from_line(parsed_line.requirement), line)
            )

        else:
            extra_pip_args.extend(shlex.split(line))
    return install_req_and_lines


def repo_names_and_requirements(
    install_reqs: List[Tuple[InstallRequirement, str]], repo_prefix: str
) -> List[Tuple[str, str]]:
    return [
        (
            bazel.sanitise_name(ir.name, prefix=repo_prefix),
            line,
        )
        for ir, line in install_reqs
    ]


def parse_whl_library_args(args: argparse.Namespace) -> Dict[str, Any]:
    whl_library_args = dict(vars(args))
    whl_library_args = arguments.deserialize_structured_args(whl_library_args)
    whl_library_args.setdefault("python_interpreter", sys.executable)

    # These arguments are not used by `whl_library`
    for arg in ("requirements_lock", "annotations"):
        if arg in whl_library_args:
            whl_library_args.pop(arg)

    return whl_library_args


def generate_parsed_requirements_contents(
    requirements_lock: Path,
    repo_prefix: str,
    whl_library_args: Dict[str, Any],
    annotations: Dict[str, str] = dict(),
) -> str:
    """
    Parse each requirement from the requirements_lock file, and prepare arguments for each
    repository rule, which will represent the individual requirements.

    Generates a requirements.bzl file containing a macro (install_deps()) which instantiates
    a repository rule for each requirment in the lock file.
    """
    install_req_and_lines = parse_install_requirements(
        requirements_lock, whl_library_args["extra_pip_args"]
    )
    repo_names_and_reqs = repo_names_and_requirements(
        install_req_and_lines, repo_prefix
    )
    all_requirements = ", ".join(
        [
            bazel.sanitised_repo_library_label(ir.name, repo_prefix=repo_prefix)
            for ir, _ in install_req_and_lines
        ]
    )
    all_whl_requirements = ", ".join(
        [
            bazel.sanitised_repo_file_label(ir.name, repo_prefix=repo_prefix)
            for ir, _ in install_req_and_lines
        ]
    )
    return textwrap.dedent(
        """\
        load("@rules_python//python/pip_install:pip_repository.bzl", "whl_library")

        all_requirements = [{all_requirements}]

        all_whl_requirements = [{all_whl_requirements}]

        _packages = {repo_names_and_reqs}
        _config = {args}
        _annotations = {annotations}

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

        def _get_annotation(requirement):
            # This expects to parse `setuptools==58.2.0     --hash=sha256:2551203ae6955b9876741a26ab3e767bb3242dafe86a32a749ea0d78b6792f11`
            # down wo `setuptools`.
            name = requirement.split(" ")[0].split("=")[0]
            return _annotations.get(name)

        def install_deps():
            for name, requirement in _packages:
                whl_library(
                    name = name,
                    requirement = requirement,
                    annotation = _get_annotation(requirement),
                    **_config,
                )
        """.format(
            all_requirements=all_requirements,
            all_whl_requirements=all_whl_requirements,
            annotations=json.dumps(annotations),
            args=whl_library_args,
            data_label=bazel.DATA_LABEL,
            dist_info_label=bazel.DIST_INFO_LABEL,
            entry_point_prefix=bazel.WHEEL_ENTRY_POINT_PREFIX,
            py_library_label=bazel.PY_LIBRARY_LABEL,
            repo_names_and_reqs=repo_names_and_reqs,
            repo_prefix=repo_prefix,
            wheel_file_label=bazel.WHEEL_FILE_LABEL,
        )
    )


def coerce_to_bool(option):
    return str(option).lower() == "true"


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
    parser.add_argument(
        "--annotations",
        type=annotation.annotations_map_from_str_path,
        help="A json encoded file containing annotations for rendered packages.",
    )
    arguments.parse_common_args(parser)
    args = parser.parse_args()

    whl_library_args = parse_whl_library_args(args)

    # Check for any annotations which match packages in the locked requirements file
    install_requirements = parse_install_requirements(
        args.requirements_lock, whl_library_args["extra_pip_args"]
    )
    req_names = sorted([req.name for req, _ in install_requirements])
    annotations = args.annotations.collect(req_names)

    # Write all rendered annotation files and generate a list of the labels to write to the requirements file
    annotated_requirements = dict()
    for name, content in annotations.items():
        annotation_path = Path(name + ".annotation.json")
        annotation_path.write_text(json.dumps(content, indent=4))
        annotated_requirements.update(
            {
                name: "@{}//:{}.annotation.json".format(
                    args.repo_prefix.rstrip("_"), name
                )
            }
        )

    with open("requirements.bzl", "w") as requirement_file:
        requirement_file.write(
            generate_parsed_requirements_contents(
                requirements_lock=args.requirements_lock,
                repo_prefix=args.repo_prefix,
                whl_library_args=whl_library_args,
                annotations=annotated_requirements,
            )
        )
