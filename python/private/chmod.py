#! /usr/bin/env python3

# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Provides a `chmod` implementation that recursively removes write permissions.
"""

from __future__ import annotations

from itertools import chain
from argparse import ArgumentParser
from pathlib import Path
from stat import S_IWGRP, S_IWOTH, S_IWUSR


def readonly(value: str) -> int:
    if value != "ugo-w":
        raise ValueError("Only `ugo-w` is supported")

    return ~(S_IWUSR | S_IWGRP | S_IWOTH)


def directory(value: str) -> Path:
    path = Path(value)

    if not path.exists():
        raise ValueError(f"`{path}` must exist")

    if not path.is_dir():
        raise ValueError("Must be a directory")

    return path


def main():
    parser = ArgumentParser(prog="chmod", description="Change file mode bits.")
    parser.add_argument(
        "-R",
        "--recursive",
        action="store_true",
        help="Recursively set permissions.",
        required=True,
    )
    parser.add_argument(
        "mask",
        metavar="MODE",
        help="Symbolic mode settings.",
        type=readonly,
    )
    parser.add_argument(
        "directory",
        metavar="FILE",
        help="Filepath(s) to operate on.",
        type=directory,
    )
    args = parser.parse_args()

    for path in chain((args.directory,), args.directory.glob("**/*")):
        stat = path.stat()
        path.chmod(stat.st_mode & args.mask)


if __name__ == "__main__":
    main()
