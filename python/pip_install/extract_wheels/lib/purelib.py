"""Functions to make purelibs Bazel compatible"""
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

    if "Root-Is-Purelib" not in wheel_metadata_dict:
        raise ValueError(
            "Invalid WHEEL file '%s'. Expected key 'Root-Is-Purelib'."
            % wheel_metadata_file_path
        )
    root_is_purelib = wheel_metadata_dict["Root-Is-Purelib"]

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


def _spread_purelib(purelib_dir: pathlib.Path, root_dir: str) -> None:
    """Recursively moves all sibling directories of the purelib to the root.

    Args:
        purelib_dir: The directory of the purelib.
        root_dir: The directory to move files into.
    """
    for grandchild in purelib_dir.iterdir():
        # Some purelib Wheels, like Tensorflow 2.0.0, have directories
        # split between the root and the purelib directory. In this case
        # we should leave the purelib 'sibling' alone.
        # See: https://github.com/dillon-giacoppo/rules_python_external/issues/8
        if not pathlib.Path(root_dir, grandchild.name).exists():
            shutil.move(
                src=str(grandchild), dst=root_dir,
            )
