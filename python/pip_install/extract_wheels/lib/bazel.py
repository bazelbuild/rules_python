"""Utility functions to manipulate Bazel files"""
import json
import os
import shutil
import textwrap
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set

from python.pip_install.extract_wheels.lib import (
    annotation,
    namespace_pkgs,
    purelib,
    wheel,
)

WHEEL_FILE_LABEL = "whl"
PY_LIBRARY_LABEL = "pkg"
DATA_LABEL = "data"
DIST_INFO_LABEL = "dist_info"
WHEEL_ENTRY_POINT_PREFIX = "rules_python_wheel_entry_point"


def generate_entry_point_contents(
    entry_point: str, shebang: str = "#!/usr/bin/env python3"
) -> str:
    """Generate the contents of an entry point script.

    Args:
        entry_point (str): The name of the entry point as show in the
            `console_scripts` section of `entry_point.txt`.
        shebang (str, optional): The shebang to use for the entry point python
            file.

    Returns:
        str: A string of python code.
    """
    module, method = entry_point.split(":", 1)
    return textwrap.dedent(
        """\
        {shebang}
        import sys
        from {module} import {method}
        if __name__ == "__main__":
            rc = {method}()
            sys.exit({method}())
        """.format(
            shebang=shebang, module=module, method=method
        )
    )


def generate_entry_point_rule(script: str, pkg: str) -> str:
    """Generate a Bazel `py_binary` rule for an entry point script.

    Note that the script is used to determine the name of the target. The name of
    entry point targets should be uniuqe to avoid conflicts with existing sources or
    directories within a wheel.

    Args:
        script (str): The path to the entry point's python file.
        pkg (str): The package owning the entry point. This is expected to
            match up with the `py_library` defined for each repository.


    Returns:
        str: A `py_binary` instantiation.
    """
    name = os.path.splitext(script)[0]
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


def generate_copy_commands(src, dest, is_executable=False) -> str:
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


def generate_build_file_contents(
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

    dist_info_ignores = [
        # RECORD is known to contain sha256 checksums of files which might include the checksums
        # of generated files produced when wheels are installed. The file is ignored to avoid
        # Bazel caching issues.
        "**/*.dist-info/RECORD",
    ]

    data_exclude = list(
        set(
            [
                "*.whl",
                "**/__pycache__/**",
                "**/* *",
                "**/*.py",
                "**/*.pyc",
                "BUILD.bazel",
                "WORKSPACE",
                f"{WHEEL_ENTRY_POINT_PREFIX}*.py",
            ]
            + data_exclude
            + dist_info_ignores
        )
    )

    return "\n".join(
        [
            textwrap.dedent(
                """\
        load("@rules_python//python:defs.bzl", "py_library", "py_binary")
        load("@rules_python//third_party/github.com/bazelbuild/bazel-skylib/rules:copy_file.bzl", "copy_file")

        package(default_visibility = ["//visibility:public"])

        filegroup(
            name = "{dist_info_label}",
            srcs = glob(["*.dist-info/**"], allow_empty = True),
        )

        filegroup(
            name = "{data_label}",
            srcs = glob(["*.data/**"], allow_empty = True),
        )

        filegroup(
            name = "{whl_file_label}",
            srcs = glob(["*.whl"], allow_empty = True),
            data = [{whl_file_deps}],
        )

        py_library(
            name = "{name}",
            srcs = glob(["**/*.py"], exclude={srcs_exclude}, allow_empty = True),
            data = {data} + glob(["**/*"], exclude={data_exclude}),
            # This makes this directory a top-level in the python import
            # search path for anything that depends on this.
            imports = ["."],
            deps = [{dependencies}],
            tags = [{tags}],
        )
        """.format(
                    name=name,
                    dependencies=",".join(sorted(dependencies)),
                    data_exclude=json.dumps(sorted(data_exclude)),
                    whl_file_label=WHEEL_FILE_LABEL,
                    whl_file_deps=",".join(sorted(whl_file_deps)),
                    tags=",".join(sorted(['"%s"' % t for t in tags])),
                    data_label=DATA_LABEL,
                    dist_info_label=DIST_INFO_LABEL,
                    entry_point_prefix=WHEEL_ENTRY_POINT_PREFIX,
                    srcs_exclude=json.dumps(sorted(srcs_exclude)),
                    data=json.dumps(sorted(data)),
                )
            )
        ]
        + additional_content
    )


def generate_requirements_file_contents(repo_name: str, targets: Iterable[str]) -> str:
    """Generate a requirements.bzl file for a given pip repository

    The file allows converting the PyPI name to a bazel label. Additionally, it adds a function which can glob all the
    installed dependencies.

    Args:
        repo_name: the name of the pip repository
        targets: a list of Bazel labels pointing to all the generated targets

    Returns:
        A complete requirements.bzl file as a string
    """

    sorted_targets = sorted(targets)
    requirement_labels = ",".join(sorted_targets)
    whl_requirement_labels = ",".join(
        '"{}:whl"'.format(target.strip('"')) for target in sorted_targets
    )
    return textwrap.dedent(
        """\
        all_requirements = [{requirement_labels}]

        all_whl_requirements = [{whl_requirement_labels}]

        def requirement(name):
           name_key = name.replace("-", "_").replace(".", "_").lower()
           return "{repo}//pypi__" + name_key

        def whl_requirement(name):
            return requirement(name) + ":{whl_file_label}"

        def data_requirement(name):
            return requirement(name) + ":{data_label}"

        def dist_info_requirement(name):
            return requirement(name) + ":{dist_info_label}"

        def entry_point(pkg, script = None):
            if not script:
                script = pkg
            return requirement(pkg) + ":{entry_point_prefix}_" + script

        def install_deps():
            fail("install_deps() only works if you are creating an incremental repo. Did you mean to use pip_parse()?")
        """.format(
            repo=repo_name,
            requirement_labels=requirement_labels,
            whl_requirement_labels=whl_requirement_labels,
            whl_file_label=WHEEL_FILE_LABEL,
            data_label=DATA_LABEL,
            dist_info_label=DIST_INFO_LABEL,
            entry_point_prefix=WHEEL_ENTRY_POINT_PREFIX,
        )
    )


def sanitise_name(name: str, prefix: str) -> str:
    """Sanitises the name to be compatible with Bazel labels.

    There are certain requirements around Bazel labels that we need to consider. From the Bazel docs:

        Package names must be composed entirely of characters drawn from the set A-Z, a–z, 0–9, '/', '-', '.', and '_',
        and cannot start with a slash.

    Due to restrictions on Bazel labels we also cannot allow hyphens. See
    https://github.com/bazelbuild/bazel/issues/6841

    Further, rules-python automatically adds the repository root to the PYTHONPATH, meaning a package that has the same
    name as a module is picked up. We workaround this by prefixing with `pypi__`. Alternatively we could require
    `--noexperimental_python_import_all_repositories` be set, however this breaks rules_docker.
    See: https://github.com/bazelbuild/bazel/issues/2636
    """

    return prefix + name.replace("-", "_").replace(".", "_").lower()


def setup_namespace_pkg_compatibility(wheel_dir: str) -> None:
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


def sanitised_library_label(whl_name: str, prefix: str) -> str:
    return '"//%s"' % sanitise_name(whl_name, prefix)


def sanitised_file_label(whl_name: str, prefix: str) -> str:
    return '"//%s:%s"' % (sanitise_name(whl_name, prefix), WHEEL_FILE_LABEL)


def _whl_name_to_repo_root(whl_name: str, repo_prefix: str) -> str:
    return "@{}//".format(sanitise_name(whl_name, prefix=repo_prefix))


def sanitised_repo_library_label(whl_name: str, repo_prefix: str) -> str:
    return '"{}:{}"'.format(
        _whl_name_to_repo_root(whl_name, repo_prefix), PY_LIBRARY_LABEL
    )


def sanitised_repo_file_label(whl_name: str, repo_prefix: str) -> str:
    return '"{}:{}"'.format(
        _whl_name_to_repo_root(whl_name, repo_prefix), WHEEL_FILE_LABEL
    )


def extract_wheel(
    wheel_file: str,
    extras: Dict[str, Set[str]],
    pip_data_exclude: List[str],
    enable_implicit_namespace_pkgs: bool,
    repo_prefix: str,
    incremental: bool = False,
    incremental_dir: Path = Path("."),
    annotation: Optional[annotation.Annotation] = None,
) -> Optional[str]:
    """Extracts wheel into given directory and creates py_library and filegroup targets.

    Args:
        wheel_file: the filepath of the .whl
        extras: a list of extras to add as dependencies for the installed wheel
        pip_data_exclude: list of file patterns to exclude from the generated data section of the py_library
        enable_implicit_namespace_pkgs: if true, disables conversion of implicit namespace packages and will unzip as-is
        incremental: If true the extract the wheel in a format suitable for an external repository. This
            effects the names of libraries and their dependencies, which point to other external repositories.
        incremental_dir: An optional override for the working directory of incremental builds.
        annotation: An optional set of annotations to apply to the BUILD contents of the wheel.

    Returns:
        The Bazel label for the extracted wheel, in the form '//path/to/wheel'.
    """

    whl = wheel.Wheel(wheel_file)
    if incremental:
        directory = incremental_dir
    else:
        directory = sanitise_name(whl.name, prefix=repo_prefix)

        os.mkdir(directory)
        # copy the original wheel
        shutil.copy(whl.path, directory)
    whl.unzip(directory)

    # Note: Order of operations matters here
    purelib.spread_purelib_into_root(directory)

    if not enable_implicit_namespace_pkgs:
        setup_namespace_pkg_compatibility(directory)

    extras_requested = extras[whl.name] if whl.name in extras else set()
    whl_deps = sorted(whl.dependencies(extras_requested))

    if incremental:
        sanitised_dependencies = [
            sanitised_repo_library_label(d, repo_prefix=repo_prefix) for d in whl_deps
        ]
        sanitised_wheel_file_dependencies = [
            sanitised_repo_file_label(d, repo_prefix=repo_prefix) for d in whl_deps
        ]
    else:
        sanitised_dependencies = [
            sanitised_library_label(d, prefix=repo_prefix) for d in whl_deps
        ]
        sanitised_wheel_file_dependencies = [
            sanitised_file_label(d, prefix=repo_prefix) for d in whl_deps
        ]

    library_name = (
        PY_LIBRARY_LABEL if incremental else sanitise_name(whl.name, repo_prefix)
    )

    directory_path = Path(directory)
    entry_points = []
    for name, entry_point in sorted(whl.entry_points().items()):
        entry_point_script = f"{WHEEL_ENTRY_POINT_PREFIX}_{name}.py"
        (directory_path / entry_point_script).write_text(
            generate_entry_point_contents(entry_point)
        )
        entry_points.append(
            generate_entry_point_rule(
                entry_point_script,
                library_name,
            )
        )

    with open(os.path.join(directory, "BUILD.bazel"), "w") as build_file:
        additional_content = entry_points
        data = []
        data_exclude = pip_data_exclude
        srcs_exclude = []
        if annotation:
            for src, dest in annotation.copy_files.items():
                data.append(dest)
                additional_content.append(generate_copy_commands(src, dest))
            for src, dest in annotation.copy_executables.items():
                data.append(dest)
                additional_content.append(
                    generate_copy_commands(src, dest, is_executable=True)
                )
            data.extend(annotation.data)
            data_exclude.extend(annotation.data_exclude_glob)
            srcs_exclude.extend(annotation.srcs_exclude_glob)
            if annotation.additive_build_content:
                additional_content.append(annotation.additive_build_content)

        contents = generate_build_file_contents(
            name=PY_LIBRARY_LABEL
            if incremental
            else sanitise_name(whl.name, repo_prefix),
            dependencies=sanitised_dependencies,
            whl_file_deps=sanitised_wheel_file_dependencies,
            data_exclude=data_exclude,
            data=data,
            srcs_exclude=srcs_exclude,
            tags=["pypi_name=" + whl.name, "pypi_version=" + whl.metadata.version],
            additional_content=additional_content,
        )
        build_file.write(contents)

    if not incremental:
        os.remove(whl.path)
        return f"//{directory}"
    return None
