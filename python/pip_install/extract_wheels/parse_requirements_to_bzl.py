import argparse
import json
import os
import shlex
import sys
import textwrap
import warnings
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

from python.pip_install.extract_wheels import annotation, arguments, bazel


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
        "library_overrides",
    ):
        if arg in whl_library_args:
            whl_library_args.pop(arg)

    return whl_library_args


def _create_alias_package(
    alias_name: str,
    py_library_selection: Dict[str, str],
):
    # The directory name is just the sanitized name.
    os.mkdir(alias_name)

    py_library_selection = json.dumps(py_library_selection)

    build_file_content = textwrap.dedent(
        """\

        package(default_visibility = ["//visibility:public"])

        alias(
            name = "{py_library_label}",
            actual = select({py_library_selection}),
        )
        """.format(
            py_library_label=alias_name,
            py_library_selection=py_library_selection,
        )
    )

    with open(os.path.join(alias_name, "BUILD.bazel"), "w", encoding="utf-8") as f:
        f.write(build_file_content)


def create_alias_packages(
    repo_prefix: str,
    install_requirements: List[Tuple[InstallRequirement, str]],
    library_overrides: Dict[str, Dict[str, str]],
):
    """Create alias packages and targets for each requirement."""
    for ir, _ in install_requirements:
        # The 'actual' library is the one in the incrementally fetched repo.
        # We need to strip the quotes here as we will encode w/ json.
        actual_library = bazel.sanitised_repo_library_label(
            ir.name, repo_prefix=repo_prefix
        )
        actual_library = actual_library.replace('"', "")

        alias_name = bazel.sanitise_name(ir.name, "")

        # Apply any overrides on top. We pop the keys here so we can report
        # unused libraries to the user. Currently this only accepts overrides
        # which use the alias (sanitized) name.
        py_library_selection = {
            "//conditions:default": actual_library,
            **library_overrides.pop(alias_name, {}),
        }

        _create_alias_package(
            alias_name=alias_name, py_library_selection=py_library_selection
        )

    # By default, warn about overrides which aren't present in the requirements
    # file, but create repos for these overrides anyway. This is useful in cases
    # where the actual combination of libraries is unsupported but it works with
    # the user's custom override(s).
    # TODO(corypaik): Parameterize this behavior so that the users can whitelist
    # specific libraries or throw an error instead.
    if len(library_overrides) > 0:
        warnings.warn(
            "Ignoring library overrides for packages not present in the "
            f"requirements file: {library_overrides}"
        )

    for alias_name, py_library_selection in library_overrides.items():
        _create_alias_package(
            alias_name=alias_name, py_library_selection=py_library_selection
        )


def generate_parsed_requirements_contents(
    requirements_lock: Path,
    repo: str,
    repo_prefix: str,
    parent_repo_name: str,
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
    # Use the alias targets for `all_requirements`.
    all_requirements = ", ".join(
        [
            bazel.sanitised_alias_repo_library_label(
                repo=parent_repo_name, name=ir.name
            )
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


def parse_json_from_file(option):
    content = Path(option).read_text()
    return json.loads(content) if content.strip() != "" else {}


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
    parser.add_argument(
        "--library_overrides",
        type=parse_json_from_file,
        help="A json encoded file containing library overrides for packages.",
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

    # Generate build files for each library.
    create_alias_packages(
        repo_prefix=args.repo_prefix,
        install_requirements=install_requirements,
        library_overrides=args.library_overrides,
    )

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
            parent_repo_name=args.repo,
            whl_library_args=whl_library_args,
            annotations=annotated_requirements,
            bzlmod=args.bzlmod,
        )
    )


if __name__ == "__main__":
    with open("requirements.bzl", "w") as requirement_file:
        main(requirement_file)
