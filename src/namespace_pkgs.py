import os
import glob

from typing import Set


# See https://packaging.python.org/guides/packaging-namespace-packages/#pkgutil-style-namespace-packages
PKGUTIL_STYLE_NS_PKG_INIT_CONTENTS = (
    "# __path__ manipulation added by rules_python_external to support namespace pkgs.\n"
    "__path__ = __import__('pkgutil').extend_path(__path__, __name__)\n"
)


def pkg_resources_style_namespace_packages(extracted_whl_directory) -> Set[str]:
    """
    "While this approach is no longer recommended, it is widely present in most existing namespace packages." - PyPA
    See https://packaging.python.org/guides/packaging-namespace-packages/#pkg-resources-style-namespace-packages
    """
    namespace_pkg_dirs = set()

    dist_info_dirs = glob.glob(os.path.join(extracted_whl_directory, "*.dist-info"))
    if not dist_info_dirs:
        raise ValueError(f"No *.dist-info directory found. {extracted_whl_directory} is not a valid Wheel.")
    elif len(dist_info_dirs) > 1:
        raise ValueError(f"Found more than 1 *.dist-info directory. {extracted_whl_directory} is not a valid Wheel.")
    else:
        dist_info = dist_info_dirs[0]
    namespace_packages_record_file = os.path.join(dist_info, "namespace_packages.txt")
    if os.path.exists(namespace_packages_record_file):
        with open(namespace_packages_record_file) as nspkg:
            for line in nspkg.readlines():
                namespace = line.strip().replace(".", os.sep)
                if namespace:
                    namespace_pkg_dirs.add(
                        os.path.join(extracted_whl_directory, namespace)
                    )
    return namespace_pkg_dirs


def implicit_namespace_packages(directory, ignored_dirnames=None) -> Set[str]:
    namespace_pkg_dirs = set()
    for dirpath, dirnames, filenames in os.walk(directory, topdown=True):
        # We are only interested in dirs with no init file
        if "__init__.py" in filenames:
            dirnames[:] = []  # Remove dirnames from search
            continue

        for ignored_dir in (ignored_dirnames or []):
            if ignored_dir in dirnames:
                dirnames.remove(ignored_dir)

        non_empty_directory = (dirnames or filenames)
        if (
            non_empty_directory and
            # The root of the directory should never be an implicit namespace
            dirpath != directory
        ):
            namespace_pkg_dirs.add(dirpath)
    return namespace_pkg_dirs


def add_pkgutil_style_namespace_pkg_init(dir_path: str) -> None:
    """TODO"""
    ns_pkg_init_filepath = os.path.join(dir_path, "__init__.py")

    if os.path.isfile(ns_pkg_init_filepath):
        raise ValueError(f"{dir_path} already contains an __init__.py file.")
    with open(ns_pkg_init_filepath, "w") as ns_pkg_init_f:
        ns_pkg_init_f.write(PKGUTIL_STYLE_NS_PKG_INIT_CONTENTS)
