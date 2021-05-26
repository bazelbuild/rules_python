"""Utility functions to discover python package types"""
import os
import pathlib  # supported in >= 3.4
import textwrap
from typing import Set, List, Optional


def implicit_namespace_packages(
    directory: str, ignored_dirnames: Optional[List[str]] = None
) -> Set[str]:
    """Discovers namespace packages implemented using the 'native namespace packages' method.

    AKA 'implicit namespace packages', which has been supported since Python 3.3.
    See: https://packaging.python.org/guides/packaging-namespace-packages/#native-namespace-packages

    Args:
        directory: The root directory to recursively find packages in.
        ignored_dirnames: A list of directories to exclude from the search

    Returns:
        The set of directories found under root to be packages using the native namespace method.
    """
    namespace_pkg_dirs = set()
    for dirpath, dirnames, filenames in os.walk(directory, topdown=True):
        # We are only interested in dirs with no __init__.py file
        if "__init__.py" in filenames:
            dirnames[:] = []  # Remove dirnames from search
            continue

        for ignored_dir in ignored_dirnames or []:
            if ignored_dir in dirnames:
                dirnames.remove(ignored_dir)

        non_empty_directory = dirnames or filenames
        if (
            non_empty_directory
            and
            # The root of the directory should never be an implicit namespace
            dirpath != directory
        ):
            namespace_pkg_dirs.add(dirpath)

    return namespace_pkg_dirs


def add_pkgutil_style_namespace_pkg_init(dir_path: str) -> None:
    """Adds 'pkgutil-style namespace packages' init file to the given directory

    See: https://packaging.python.org/guides/packaging-namespace-packages/#pkgutil-style-namespace-packages

    Args:
        dir_path: The directory to create an __init__.py for.

    Raises:
        ValueError: If the directory already contains an __init__.py file
    """
    ns_pkg_init_filepath = os.path.join(dir_path, "__init__.py")

    if os.path.isfile(ns_pkg_init_filepath):
        raise ValueError("%s already contains an __init__.py file." % dir_path)

    with open(ns_pkg_init_filepath, "w") as ns_pkg_init_f:
        # See https://packaging.python.org/guides/packaging-namespace-packages/#pkgutil-style-namespace-packages
        ns_pkg_init_f.write(
            textwrap.dedent(
                """\
                # __path__ manipulation added by rules_python_external to support namespace pkgs.
                __path__ = __import__('pkgutil').extend_path(__path__, __name__)
                """
            )
        )


def _includes_python_modules(files: List[str]) -> bool:
    """
    In order to only transform directories that Python actually considers namespace pkgs
    we need to detect if a directory includes Python modules.

    Which files are loadable as modules is extension based, and the particular set of extensions
    varies by platform.

    See:
    1. https://github.com/python/cpython/blob/7d9d25dbedfffce61fc76bc7ccbfa9ae901bf56f/Lib/importlib/machinery.py#L19
    2. PEP 420 -- Implicit Namespace Packages, Specification - https://www.python.org/dev/peps/pep-0420/#specification
    3. dynload_shlib.c and dynload_win.c in python/cpython.
    """
    module_suffixes = {
        ".py",  # Source modules
        ".pyc",  # Compiled bytecode modules
        ".so",  # Unix extension modules
        ".pyd"  # https://docs.python.org/3/faq/windows.html#is-a-pyd-file-the-same-as-a-dll
    }
    return any(
        pathlib.Path(f).suffix in module_suffixes
        for f
        in files
    )
