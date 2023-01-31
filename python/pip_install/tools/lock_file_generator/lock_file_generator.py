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
import shlex
import sys
import textwrap
from pathlib import Path
from typing import Any, Dict, List, TextIO, Tuple

from pip._internal.network.session import PipSession
from pip._internal.req import constructors
from pip._internal.req.req_file import (
    RequirementsFileParser,
    get_file_content,
    get_line_parser,
    preprocess,
)
from pip._internal.req.req_install import InstallRequirement

from python.pip_install.tools.lib import annotation, arguments, bazel


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
    unpinned_reqs = []
    for parsed_line, (_, line) in zip(
        parser.parse(requirements_lock, constraint=False), preprocess(content)
    ):
        if parsed_line.is_requirement:
            install_req = constructors.install_req_from_line(parsed_line.requirement)
            if (
                # PEP-440 direct references are considered pinned
                # See: https://peps.python.org/pep-0440/#direct-references and https://peps.python.org/pep-0508/
                not install_req.link
                and not install_req.is_pinned
            ):
                unpinned_reqs.append(str(install_req))
            install_req_and_lines.append((install_req, line))

        else:
            extra_pip_args.extend(shlex.split(line))

    if len(unpinned_reqs) > 0:
        unpinned_reqs_str = "\n".join(unpinned_reqs)
        raise RuntimeError(
            f"""\
The `requirements_lock` file must be fully pinned. See `compile_pip_requirements`.
Alternatively, use `pip-tools` or a similar mechanism to produce a pinned lockfile.

The following requirements were not pinned:
{unpinned_reqs_str}"""
        )

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
    for arg in (
        "requirements_lock",
        "requirements_lock_label",
        "annotations",
        "bzlmod",
    ):
        if arg in whl_library_args:
            whl_library_args.pop(arg)

    return whl_library_args


def generate_parsed_requirements_contents(
    requirements_lock: Path,
    repo: str,
    repo_prefix: str,
    whl_library_args: Dict[str, Any],
    annotations: Dict[str, str] = dict(),
    bzlmod: bool = False,
) -> str:
    """
    Parse each requirement from the requirements_lock file, and prepare arguments for each
    repository rule, which will represent the individual requirements.

    Generates a requirements.bzl file containing a macro (install_deps()) which instantiates
    a repository rule for each requirement in the lock file.
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

    install_deps_macro = """
        def install_deps(**whl_library_kwargs):
            whl_config = dict(_config)
            whl_config.update(whl_library_kwargs)
            for name, requirement in _packages:
                whl_library(
                    name = name,
                    requirement = requirement,
                    annotation = _get_annotation(requirement),
                    **whl_config
                )
"""
    return textwrap.dedent(
        (
            """\

        load("@rules_python//python/pip_install:pip_repository.bzl", "whl_library")

        all_requirements = [{all_requirements}]

        all_whl_requirements = [{all_whl_requirements}]

        _packages = {repo_names_and_reqs}
        _config = {args}
        _annotations = {annotations}
        _bzlmod = {bzlmod}

        def _clean_name(name):
            return name.replace("-", "_").replace(".", "_").lower()

        def requirement(name):
            if _bzlmod:
                return "@@{repo}//:" + _clean_name(name) + "_{py_library_label}"
            return "@{repo_prefix}" + _clean_name(name) + "//:{py_library_label}"

        def whl_requirement(name):
            if _bzlmod:
                return "@@{repo}//:" + _clean_name(name) + "_{wheel_file_label}"
            return "@{repo_prefix}" + _clean_name(name) + "//:{wheel_file_label}"

        def data_requirement(name):
            if _bzlmod:
                return "@@{repo}//:" + _clean_name(name) + "_{data_label}"
            return "@{repo_prefix}" + _clean_name(name) + "//:{data_label}"

        def dist_info_requirement(name):
            if _bzlmod:
                return "@@{repo}//:" + _clean_name(name) + "_{dist_info_label}"
            return "@{repo_prefix}" + _clean_name(name) + "//:{dist_info_label}"

        def entry_point(pkg, script = None):
            if not script:
                script = pkg
            return "@{repo_prefix}" + _clean_name(pkg) + "//:{entry_point_prefix}_" + script

        def _get_annotation(requirement):
            # This expects to parse `setuptools==58.2.0     --hash=sha256:2551203ae6955b9876741a26ab3e767bb3242dafe86a32a749ea0d78b6792f11`
            # down wo `setuptools`.
            name = requirement.split(" ")[0].split("=")[0].split("[")[0]
            return _annotations.get(name)
"""
            + (install_deps_macro if not bzlmod else "")
        ).format(
            all_requirements=all_requirements,
            all_whl_requirements=all_whl_requirements,
            annotations=json.dumps(annotations),
            args=dict(sorted(whl_library_args.items())),
            data_label=bazel.DATA_LABEL,
            dist_info_label=bazel.DIST_INFO_LABEL,
            entry_point_prefix=bazel.WHEEL_ENTRY_POINT_PREFIX,
            py_library_label=bazel.PY_LIBRARY_LABEL,
            repo_names_and_reqs=repo_names_and_reqs,
            repo=repo,
            repo_prefix=repo_prefix,
            wheel_file_label=bazel.WHEEL_FILE_LABEL,
            bzlmod=bzlmod,
        )
    )


def coerce_to_bool(option):
    return str(option).lower() == "true"


def main(output: TextIO) -> None:
    """Args:

    output: where to write the resulting starlark, such as sys.stdout or an open file
    """
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
        "--requirements_lock_label",
        help="Label used to declare the requirements.lock, included in comments in the file.",
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
    parser.add_argument(
        "--bzlmod",
        type=coerce_to_bool,
        default=False,
        help="Whether this script is run under bzlmod. Under bzlmod we don't generate the install_deps() macro as it isn't needed.",
    )
    arguments.parse_common_args(parser)
    args = parser.parse_args()

    whl_library_args = parse_whl_library_args(args)

    # Check for any annotations which match packages in the locked requirements file
    install_requirements = parse_install_requirements(
        args.requirements_lock, whl_library_args["extra_pip_args"]
    )
    req_names = sorted([req.name for req, _ in install_requirements])
    annotations = args.annotations.collect(req_names) if args.annotations else {}

    # Write all rendered annotation files and generate a list of the labels to write to the requirements file
    annotated_requirements = dict()
    for name, content in annotations.items():
        annotation_path = Path(name + ".annotation.json")
        annotation_path.write_text(json.dumps(content, indent=4))
        annotated_requirements.update(
            {
                name: "@{}//:{}.annotation.json".format(
                    args.repo, name
                )
            }
        )

    output.write(
        textwrap.dedent(
            """\
        \"\"\"Starlark representation of locked requirements.

        @generated by rules_python pip_parse repository rule
        from {}
        \"\"\"
        """.format(
                args.requirements_lock_label
            )
        )
    )

    output.write(
        generate_parsed_requirements_contents(
            requirements_lock=args.requirements_lock,
            repo=args.repo,
            repo_prefix=args.repo_prefix,
            whl_library_args=whl_library_args,
            annotations=annotated_requirements,
            bzlmod=args.bzlmod,
        )
    )


if __name__ == "__main__":
    with open("requirements.bzl", "w") as requirement_file:
        main(requirement_file)
