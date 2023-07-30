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
import errno
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Dict, Iterable, List, Optional, Set, Tuple

from pip._vendor.packaging.utils import canonicalize_name

from python.pip_install.tools.lib import annotation, arguments, bazel
from python.pip_install.tools.wheel_installer import namespace_pkgs, wheel


def _configure_reproducible_wheels() -> None:
    """Modifies the environment to make wheel building reproducible.
    Wheels created from sdists are not reproducible by default. We can however workaround this by
    patching in some configuration with environment variables.
    """

    # wheel, by default, enables debug symbols in GCC. This incidentally captures the build path in the .so file
    # We can override this behavior by disabling debug symbols entirely.
    # https://github.com/pypa/pip/issues/6505
    if "CFLAGS" in os.environ:
        os.environ["CFLAGS"] += " -g0"
    else:
        os.environ["CFLAGS"] = "-g0"

    # set SOURCE_DATE_EPOCH to 1980 so that we can use python wheels
    # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/python.section.md#python-setuppy-bdist_wheel-cannot-create-whl
    if "SOURCE_DATE_EPOCH" not in os.environ:
        os.environ["SOURCE_DATE_EPOCH"] = "315532800"

    # Python wheel metadata files can be unstable.
    # See https://bitbucket.org/pypa/wheel/pull-requests/74/make-the-output-of-metadata-files/diff
    if "PYTHONHASHSEED" not in os.environ:
        os.environ["PYTHONHASHSEED"] = "0"


def _parse_requirement_for_extra(
    requirement: str,
) -> Tuple[Optional[str], Optional[Set[str]]]:
    """Given a requirement string, returns the requirement name and set of extras, if extras specified.
    Else, returns (None, None)
    """

    # https://www.python.org/dev/peps/pep-0508/#grammar
    extras_pattern = re.compile(
        r"^\s*([0-9A-Za-z][0-9A-Za-z_.\-]*)\s*\[\s*([0-9A-Za-z][0-9A-Za-z_.\-]*(?:\s*,\s*[0-9A-Za-z][0-9A-Za-z_.\-]*)*)\s*\]"
    )

    matches = extras_pattern.match(requirement)
    if matches:
        return (
            canonicalize_name(matches.group(1)),
            {extra.strip() for extra in matches.group(2).split(",")},
        )

    return None, None


def _setup_namespace_pkg_compatibility(wheel_dir: str) -> None:
    """Converts native namespace packages to pkgutil-style packages

    Namespace packages can be created in one of three ways. They are detailed here:
    https://packaging.python.org/guides/packaging-namespace-packages/#creating-a-namespace-package

    'pkgutil-style namespace packages' (2) and 'pkg_resources-style namespace packages' (3) works in Bazel, but
    'native namespace packages' (1) do not.

    We ensure compatibility with Bazel of method 1 by converting them into method 2.

    Args:
        wheel_dir: the directory of the wheel to convert
    """

    namespace_pkg_dirs = namespace_pkgs.implicit_namespace_packages(
        wheel_dir,
        ignored_dirnames=["%s/bin" % wheel_dir],
    )

    for ns_pkg_dir in namespace_pkg_dirs:
        namespace_pkgs.add_pkgutil_style_namespace_pkg_init(ns_pkg_dir)


def _generate_entry_point_contents(
    module: str, attribute: str, shebang: str = "#!/usr/bin/env python3"
) -> str:
    """Generate the contents of an entry point script.

    Args:
        module (str): The name of the module to use.
        attribute (str): The name of the attribute to call.
        shebang (str, optional): The shebang to use for the entry point python
            file.

    Returns:
        str: A string of python code.
    """
    return textwrap.dedent(
        """\
        {shebang}
        import sys
        from {module} import {attribute}
        if __name__ == "__main__":
            sys.exit({attribute}())
        """.format(
            shebang=shebang, module=module, attribute=attribute
        )
    )


def _generate_entry_point_rule(name: str, script: str, pkg: str) -> str:
    """Generate a Bazel `py_binary` rule for an entry point script.

    Note that the script is used to determine the name of the target. The name of
    entry point targets should be uniuqe to avoid conflicts with existing sources or
    directories within a wheel.

    Args:
        name (str): The name of the generated py_binary.
        script (str): The path to the entry point's python file.
        pkg (str): The package owning the entry point. This is expected to
            match up with the `py_library` defined for each repository.


    Returns:
        str: A `py_binary` instantiation.
    """
    return textwrap.dedent(
        """\
        py_binary(
            name = "{name}",
            srcs = ["{src}"],
            # This makes this directory a top-level in the python import
            # search path for anything that depends on this.
            imports = ["."],
            deps = ["{pkg}"],
        )
        """.format(
            name=name, src=str(script).replace("\\", "/"), pkg=pkg
        )
    )


def _generate_copy_commands(src, dest, is_executable=False) -> str:
    """Generate a [@bazel_skylib//rules:copy_file.bzl%copy_file][cf] target

    [cf]: https://github.com/bazelbuild/bazel-skylib/blob/1.1.1/docs/copy_file_doc.md

    Args:
        src (str): The label for the `src` attribute of [copy_file][cf]
        dest (str): The label for the `out` attribute of [copy_file][cf]
        is_executable (bool, optional): Whether or not the file being copied is executable.
            sets `is_executable` for [copy_file][cf]

    Returns:
        str: A `copy_file` instantiation.
    """
    return textwrap.dedent(
        """\
        copy_file(
            name = "{dest}.copy",
            src = "{src}",
            out = "{dest}",
            is_executable = {is_executable},
        )
    """.format(
            src=src,
            dest=dest,
            is_executable=is_executable,
        )
    )


def _generate_build_file_contents(
    name: str,
    dependencies: List[str],
    whl_file_deps: List[str],
    data_exclude: List[str],
    tags: List[str],
    srcs_exclude: List[str] = [],
    data: List[str] = [],
    additional_content: List[str] = [],
) -> str:
    """Generate a BUILD file for an unzipped Wheel

    Args:
        name: the target name of the py_library
        dependencies: a list of Bazel labels pointing to dependencies of the library
        whl_file_deps: a list of Bazel labels pointing to wheel file dependencies of this wheel.
        data_exclude: more patterns to exclude from the data attribute of generated py_library rules.
        tags: list of tags to apply to generated py_library rules.
        additional_content: A list of additional content to append to the BUILD file.

    Returns:
        A complete BUILD file as a string

    We allow for empty Python sources as for Wheels containing only compiled C code
    there may be no Python sources whatsoever (e.g. packages written in Cython: like `pymssql`).
    """

    data_exclude = list(
        set(
            [
                "**/* *",
                "**/*.py",
                "**/*.pyc",
                "**/*.pyc.*", # During pyc creation, temp files named *.pyc.NNNN are created
                # RECORD is known to contain sha256 checksums of files which might include the checksums
                # of generated files produced when wheels are installed. The file is ignored to avoid
                # Bazel caching issues.
                "**/*.dist-info/RECORD",
            ]
            + data_exclude
        )
    )

    return "\n".join(
        [
            textwrap.dedent(
                """\
        load("@rules_python//python:defs.bzl", "py_library", "py_binary")
        load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

        package(default_visibility = ["//visibility:public"])

        filegroup(
            name = "{dist_info_label}",
            srcs = glob(["site-packages/*.dist-info/**"], allow_empty = True),
        )

        filegroup(
            name = "{data_label}",
            srcs = glob(["data/**"], allow_empty = True),
        )

        filegroup(
            name = "{whl_file_label}",
            srcs = glob(["*.whl"], allow_empty = True),
            data = [{whl_file_deps}],
        )

        py_library(
            name = "{name}",
            srcs = glob(["site-packages/**/*.py"], exclude={srcs_exclude}, allow_empty = True),
            data = {data} + glob(["site-packages/**/*"], exclude={data_exclude}),
            # This makes this directory a top-level in the python import
            # search path for anything that depends on this.
            imports = ["site-packages"],
            deps = [{dependencies}],
            tags = [{tags}],
        )
        """.format(
                    name=name,
                    dependencies=",".join(sorted(dependencies)),
                    data_exclude=json.dumps(sorted(data_exclude)),
                    whl_file_label=bazel.WHEEL_FILE_LABEL,
                    whl_file_deps=",".join(sorted(whl_file_deps)),
                    tags=",".join(sorted(['"%s"' % t for t in tags])),
                    data_label=bazel.DATA_LABEL,
                    dist_info_label=bazel.DIST_INFO_LABEL,
                    entry_point_prefix=bazel.WHEEL_ENTRY_POINT_PREFIX,
                    srcs_exclude=json.dumps(sorted(srcs_exclude)),
                    data=json.dumps(sorted(data)),
                )
            )
        ]
        + additional_content
    )


def _extract_wheel(
    wheel_file: str,
    extras: Dict[str, Set[str]],
    pip_data_exclude: List[str],
    enable_implicit_namespace_pkgs: bool,
    repo_prefix: str,
    installation_dir: Path = Path("."),
    annotation: Optional[annotation.Annotation] = None,
) -> None:
    """Extracts wheel into given directory and creates py_library and filegroup targets.

    Args:
        wheel_file: the filepath of the .whl
        installation_dir: the destination directory for installation of the wheel.
        extras: a list of extras to add as dependencies for the installed wheel
        pip_data_exclude: list of file patterns to exclude from the generated data section of the py_library
        enable_implicit_namespace_pkgs: if true, disables conversion of implicit namespace packages and will unzip as-is
        annotation: An optional set of annotations to apply to the BUILD contents of the wheel.
    """

    whl = wheel.Wheel(wheel_file)
    whl.unzip(installation_dir)

    if not enable_implicit_namespace_pkgs:
        _setup_namespace_pkg_compatibility(installation_dir)

    extras_requested = extras[whl.name] if whl.name in extras else set()
    # Packages may create dependency cycles when specifying optional-dependencies / 'extras'.
    # Example: github.com/google/etils/blob/a0b71032095db14acf6b33516bca6d885fe09e35/pyproject.toml#L32.
    self_edge_dep = set([whl.name])
    whl_deps = sorted(whl.dependencies(extras_requested) - self_edge_dep)

    sanitised_dependencies = [
        bazel.sanitised_repo_library_label(d, repo_prefix=repo_prefix) for d in whl_deps
    ]
    sanitised_wheel_file_dependencies = [
        bazel.sanitised_repo_file_label(d, repo_prefix=repo_prefix) for d in whl_deps
    ]

    entry_points = []
    for name, (module, attribute) in sorted(whl.entry_points().items()):
        # There is an extreme edge-case with entry_points that end with `.py`
        # See: https://github.com/bazelbuild/bazel/blob/09c621e4cf5b968f4c6cdf905ab142d5961f9ddc/src/test/java/com/google/devtools/build/lib/rules/python/PyBinaryConfiguredTargetTest.java#L174
        entry_point_without_py = f"{name[:-3]}_py" if name.endswith(".py") else name
        entry_point_target_name = (
            f"{bazel.WHEEL_ENTRY_POINT_PREFIX}_{entry_point_without_py}"
        )
        entry_point_script_name = f"{entry_point_target_name}.py"
        (installation_dir / entry_point_script_name).write_text(
            _generate_entry_point_contents(module, attribute)
        )
        entry_points.append(
            _generate_entry_point_rule(
                entry_point_target_name,
                entry_point_script_name,
                bazel.PY_LIBRARY_LABEL,
            )
        )

    with open(os.path.join(installation_dir, "BUILD.bazel"), "w") as build_file:
        additional_content = entry_points
        data = []
        data_exclude = pip_data_exclude
        srcs_exclude = []
        if annotation:
            for src, dest in annotation.copy_files.items():
                data.append(dest)
                additional_content.append(_generate_copy_commands(src, dest))
            for src, dest in annotation.copy_executables.items():
                data.append(dest)
                additional_content.append(
                    _generate_copy_commands(src, dest, is_executable=True)
                )
            data.extend(annotation.data)
            data_exclude.extend(annotation.data_exclude_glob)
            srcs_exclude.extend(annotation.srcs_exclude_glob)
            if annotation.additive_build_content:
                additional_content.append(annotation.additive_build_content)

        contents = _generate_build_file_contents(
            name=bazel.PY_LIBRARY_LABEL,
            dependencies=sanitised_dependencies,
            whl_file_deps=sanitised_wheel_file_dependencies,
            data_exclude=data_exclude,
            data=data,
            srcs_exclude=srcs_exclude,
            tags=["pypi_name=" + whl.name, "pypi_version=" + whl.version],
            additional_content=additional_content,
        )
        build_file.write(contents)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build and/or fetch a single wheel based on the requirement passed in"
    )
    parser.add_argument(
        "--requirement",
        action="store",
        required=True,
        help="A single PEP508 requirement specifier string.",
    )
    parser.add_argument(
        "--annotation",
        type=annotation.annotation_from_str_path,
        help="A json encoded file containing annotations for rendered packages.",
    )
    arguments.parse_common_args(parser)
    args = parser.parse_args()
    deserialized_args = dict(vars(args))
    arguments.deserialize_structured_args(deserialized_args)

    _configure_reproducible_wheels()

    pip_args = (
        [sys.executable, "-m", "pip"]
        + (["--isolated"] if args.isolated else [])
        + (["download", "--only-binary=:all:"] if args.download_only else ["wheel"])
        + ["--no-deps"]
        + deserialized_args["extra_pip_args"]
    )

    requirement_file = NamedTemporaryFile(mode="wb", delete=False)
    try:
        requirement_file.write(args.requirement.encode("utf-8"))
        requirement_file.flush()
        # Close the file so pip is allowed to read it when running on Windows.
        # For more information, see: https://bugs.python.org/issue14243
        requirement_file.close()
        # Requirement specific args like --hash can only be passed in a requirements file,
        # so write our single requirement into a temp file in case it has any of those flags.
        pip_args.extend(["-r", requirement_file.name])

        env = os.environ.copy()
        env.update(deserialized_args["environment"])
        # Assumes any errors are logged by pip so do nothing. This command will fail if pip fails
        subprocess.run(pip_args, check=True, env=env)
    finally:
        try:
            os.unlink(requirement_file.name)
        except OSError as e:
            if e.errno != errno.ENOENT:
                raise

    name, extras_for_pkg = _parse_requirement_for_extra(args.requirement)
    extras = {name: extras_for_pkg} if extras_for_pkg and name else dict()

    whl = next(iter(glob.glob("*.whl")))
    _extract_wheel(
        wheel_file=whl,
        extras=extras,
        pip_data_exclude=deserialized_args["pip_data_exclude"],
        enable_implicit_namespace_pkgs=args.enable_implicit_namespace_pkgs,
        repo_prefix=args.repo_prefix,
        annotation=args.annotation,
    )


if __name__ == "__main__":
    main()
