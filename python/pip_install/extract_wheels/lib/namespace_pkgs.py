"""Utility functions to discover python package types"""
import os
import textwrap
from typing import Set, List, Optional

from python.pip_install.extract_wheels.lib import wheel


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
