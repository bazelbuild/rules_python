#!/usr/bin/env python3
# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""A small script to update bazel files within the repo.

This is reused in other files updating coverage deps and pip deps.
"""

import argparse
import difflib
import pathlib
import sys


def _writelines(path: pathlib.Path, lines: list[str]):
    with open(path, "w") as f:
        f.writelines(lines)


def _difflines(path: pathlib.Path, lines: list[str]):
    with open(path) as f:
        input = f.readlines()

    rules_python = pathlib.Path(__file__).parent.parent.resolve()
    p = path.relative_to(rules_python)

    print(f"Diff of the changes that would be made to '{p}':")
    for line in difflib.unified_diff(
        input,
        lines,
        fromfile=f"a/{p}",
        tofile=f"b/{p}",
    ):
        print(line, end="")

    # Add an empty line at the end of the diff
    print()


def update_file(
    path: pathlib.Path,
    snippet: str,
    start_marker: str,
    end_marker: str,
    dry_run: bool = True,
):
    with open(path) as f:
        input = f.readlines()

    out = []
    skip = False
    for line in input:
        if skip:
            if not line.startswith(end_marker):
                continue

            skip = False

        out.append(line)

        if not line.startswith(start_marker):
            continue

        skip = True
        out.extend([f"{line}\n" for line in snippet.splitlines()])

    if dry_run:
        _difflines(path, out)
    else:
        _writelines(path, out)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument(
        "path",
        metavar="PATH",
        type=pathlib.Path,
        help="The path of the file to modify",
    )
    parser.add_argument(
        "--start",
        type=str,
        required=True,
        help="Start marker for text replacement",
    )
    parser.add_argument(
        "--end",
        type=str,
        required=True,
        help="End marker for text replacement",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Wether to write to files",
    )
    args = parser.parse_args()

    snippet = sys.stdin.read()

    assert args.path.exists()

    update_file(
        path=args.path.resolve(),
        snippet=snippet,
        start_marker=args.start,
        end_marker=args.end,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
