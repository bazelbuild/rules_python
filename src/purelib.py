import os
import pathlib
import shutil

from . import wheel


def spread_purelib_into_root(extracted_whl_directory: str) -> None:
    dist_info = wheel.get_dist_info(extracted_whl_directory)
    wheel_metadata_file_path = pathlib.Path(dist_info, "WHEEL")
    wheel_metadata_dict = wheel.parse_WHEEL_file(str(wheel_metadata_file_path))

    if "Root-Is-Purelib" not in wheel_metadata_dict:
        raise ValueError(f"Invalid WHEEL file '{wheel_metadata_file_path}'. Expected key 'Root-Is-Purelib'.")
    root_is_purelib = wheel_metadata_dict["Root-Is-Purelib"]

    if root_is_purelib.lower() == "true":
        # The Python package code is in the root of the Wheel, so no need to 'spread' anything.
        return

    dot_data_dir = wheel.get_dot_data_directory(extracted_whl_directory)
    # 'Root-Is-Purelib: false' is no guarantee a .date directory exists with
    # package code in it. eg. the 'markupsafe' package.
    if not dot_data_dir:
        return

    for child in pathlib.Path(dot_data_dir).iterdir():
        # TODO(Jonathon): Should all other potential folders get ignored? eg. 'platlib'
        if str(child).endswith("purelib"):
            _spread_purelib(child, extracted_whl_directory)


def _spread_purelib(purelib_dir, root_dir):
    for grandchild in purelib_dir.iterdir():
        # Some purelib Wheels, like Tensorflow 2.0.0, have directories
        # split between the root and the purelib directory. In this case
        # we should leave the purelib 'sibling' alone.
        # See: https://github.com/dillon-giacoppo/rules_python_external/issues/8
        if not pathlib.Path(root_dir, grandchild.name).exists():
            shutil.move(
                src=str(grandchild),
                dst=root_dir,
            )
