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
    shutil.move(dot_data_dir, extracted_whl_directory)
