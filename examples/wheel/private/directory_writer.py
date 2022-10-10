#!/usr/bin/env python3
"""The action executable of the `@rules_python//examples/wheel/private:wheel_utils.bzl%directory_writer` rule."""

import argparse
import json
from pathlib import Path
from typing import Tuple


def _file_input(value) -> Tuple[Path, str]:
    path, content = value.split("=", maxsplit=1)
    return (Path(path), json.loads(content))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--output", type=Path, required=True, help="The output directory to create."
    )
    parser.add_argument(
        "--file",
        dest="files",
        type=_file_input,
        action="append",
        help="Files to create within the `output` directory.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    args.output.mkdir(parents=True, exist_ok=True)

    for (path, content) in args.files:
        new_file = args.output / path
        new_file.parent.mkdir(parents=True, exist_ok=True)
        new_file.write_text(content)


if __name__ == "__main__":
    main()
