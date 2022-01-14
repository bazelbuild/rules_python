"""Functions to make purelibs Bazel compatible"""
import os
import pathlib
import shutil

from python.pip_install.extract_wheels.lib import wheel


def spread_purelib_into_root(wheel_dir: str) -> None:
    """Unpacks purelib directories into the root.

    Args:
         wheel_dir: The root of the extracted wheel directory.
    """
    dist_info = wheel.get_dist_info(wheel_dir)
    wheel_metadata_file_path = pathlib.Path(dist_info, "WHEEL")
    wheel_metadata_dict = wheel.parse_wheel_meta_file(str(wheel_metadata_file_path))

    # It is not guaranteed that a WHEEL file author populates 'Root-Is-Purelib'.
    # See: https://github.com/bazelbuild/rules_python/issues/435
    root_is_purelib: str = wheel_metadata_dict.get("Root-Is-Purelib", "")
    if root_is_purelib.lower() == "true":
        # The Python package code is in the root of the Wheel, so no need to 'spread' anything.
        return

    dot_data_dir = wheel.get_dot_data_directory(wheel_dir)
    # 'Root-Is-Purelib: false' is no guarantee a .data directory exists with
    # package code in it. eg. the 'markupsafe' package.
    if not dot_data_dir:
        return

    for child in pathlib.Path(dot_data_dir).iterdir():
        # TODO(Jonathon): Should all other potential folders get ignored? eg. 'platlib'
        if str(child).endswith("purelib"):
            _spread_purelib(child, wheel_dir)


def backport_copytree(src: pathlib.Path, dst: pathlib.Path):
    """Implementation similar to shutil.copytree.

    shutil.copytree before python3.8 does not allow merging one tree with
    an existing one. This function does that, while ignoring complications around symlinks, which
    can't exist is wheels (See https://bugs.python.org/issue27318).
    """
    os.makedirs(dst, exist_ok=True)
    for path in src.iterdir():
        if path.is_dir():
            backport_copytree(path, pathlib.Path(dst, path.name))
        elif not pathlib.Path(dst, path.name).exists():
            shutil.copy(path, dst)


def _spread_purelib(purelib_dir: pathlib.Path, root_dir: str) -> None:
    """Recursively moves all sibling directories of the purelib to the root.

    Args:
        purelib_dir: The directory of the purelib.
        root_dir: The directory to move files into.
    """
    for child in purelib_dir.iterdir():
        if child.is_dir():
            backport_copytree(src=child, dst=pathlib.Path(root_dir, child.name))
        elif not pathlib.Path(root_dir, child.name).exists():
            shutil.copy(
                src=str(child),
                dst=root_dir,
            )
