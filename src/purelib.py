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
    if dot_data_dir:
        for child in pathlib.Path(dot_data_dir).iterdir():
            # TODO(Jonathon): Should all other potential folders get ignored?
            if str(child).endswith("purelib"):
                for grandchild in child.iterdir():
                    shutil.move(
                        src=str(grandchild),
                        dst=extracted_whl_directory,
                    )
