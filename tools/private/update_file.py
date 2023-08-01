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

from python.runfiles import runfiles


def path_from_runfiles(input: str):
    """A helper to create a path from runfiles.

    Args:
        input: the string input to construct a path.

    Returns:
        the pathlib.Path path to a file which is verified to exist.
    """
    path = pathlib.Path(runfiles.Create().Rlocation(input))
    if not path.exists():
        raise ValueError(f"Path '{path}' does not exist")

    return path


def _writelines(path: pathlib.Path, out: str):
    with open(path, "w") as f:
        f.write(out)


def _difflines(name: str, current: str, out: str) -> str:
    return "".join(
        difflib.unified_diff(
            current.splitlines(keepends=True),
            out.splitlines(keepends=True),
            fromfile=f"a/{name}",
            tofile=f"b/{name}",
        )
    ).strip()


def update_file(
    path: pathlib.Path,
    snippet: str,
    start_marker: str,
    end_marker: str,
    dry_run: bool = True,
):
    """update a file on disk to replace text in a file between two markers.

    Args:
        path: pathlib.Path, the path to the file to be modified.
        snippet: str, the snippet of code to insert between the markers.
        start_marker: str, the text that marks the start of the region to be replaced.
        end_markr: str, the text that marks the end of the region to be replaced.
        dry_run: bool, if set to True, then the file will not be written and instead we are going to print a diff to
            stdout.
    """
    current = path.read_text()
    lines = []
    skip = False
    found_match = False
    for line in current.splitlines(keepends=True):
        if line.lstrip().startswith(start_marker.lstrip()):
            found_match = True
            lines.append(line)
            lines.append(snippet)
            skip = True
        elif skip and line.lstrip().startswith(end_marker):
            skip = False
            lines.append(line)
            continue
        elif not skip:
            lines.append(line)

    if not found_match:
        raise RuntimeError(f"could not find a match for the '{start_marker}'")
    if skip:
        raise RuntimeError(f"could not find a match for the '{end_marker}'")

    out = "".join(lines)

    assert (
        snippet in out
    ), "There is likely a BUG with the snippet not being present in the output"

    if not dry_run:
        _writelines(path, out)
    else:
        diff = _difflines(path.name, current, out)
        if diff:
            print(f"Diff of the changes that would be made to '{name}':\n{diff}")
        else:
            print(f"'{name}' is up to date")
