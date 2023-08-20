# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""entry_point generator."""

from __future__ import annotations

import argparse
import configparser
import pathlib
import sys
import textwrap

_ENTRY_POINTS_TXT = "entry_points.txt"
_TEMPLATE = """\
import sys
# When running the `py_console_script_binary` executable target via `bazel run`
# we start getting inconsistent behaviour with how it works accessing it via
# rlocationpath as in bzlmod examples. It seems that not all of the PyPI
# packages are affected by this, but without the following workaround, pylint
# seems to be not working.
if ".runfiles" not in sys.path[0]:
    sys.path = sys.path[1:]

try:
    from {module} import {attr}
except ImportError:
    entries = "\\n".join(sys.path)
    print("Printing sys.path entries for easier debugging:", file=sys.stderr)
    print(f"sys.path is:\\n{{entries}}", file=sys.stderr)
    raise

if __name__ == "__main__":
    sys.exit({entry_point}())
"""


class EntryPointsParser(configparser.ConfigParser):
    """A class handling entry_points.txt

    See https://packaging.python.org/en/latest/specifications/entry-points/
    """

    optionxform = staticmethod(str)


def run(
    *,
    entry_points: pathlib.Path,
    out: pathlib.Path,
    console_script: str,
):
    """Run the generator

    Args:
        entry_points: The entry_points.txt file to be parsed.
        out: The output file.
        console_script: The console_script entry in the entry_points.txt file.
    """
    config = EntryPointsParser()
    config.read(entry_points)

    try:
        console_scripts = dict(config["console_scripts"])
    except KeyError:
        raise RuntimeError(
            f"The package does not provide any console_scripts in it's {_ENTRY_POINTS_TXT}"
        )

    if console_script:
        try:
            entry_point = console_scripts[console_script]
        except KeyError:
            available = ", ".join(sorted(console_scripts.keys()))
            raise RuntimeError(
                f"The console_script '{console_script}' was not found, only the following are available: {available}"
            ) from None
    elif len(console_scripts) == 1:
        entry_point = next(iter(console_scripts.items()))[1]
    else:
        available = ", ".join(sorted(console_scripts.keys()))
        raise RuntimeError(
            f"Please select one of the following console scripts: {available}"
        ) from None

    module, _, entry_point = entry_point.rpartition(":")
    attr, _, _ = entry_point.partition(".")
    # TODO: handle extra in entry_point generation
    # See https://github.com/bazelbuild/rules_python/issues/1383
    # See https://packaging.python.org/en/latest/specifications/entry-points/

    with open(out, "w") as f:
        f.write(
            _TEMPLATE.format(
                module=module,
                attr=attr,
                entry_point=entry_point,
            ),
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--console-script",
        help="The console_script to generate the entry_point template for.",
    )
    parser.add_argument(
        "entry_points",
        metavar="ENTRY_POINTS_TXT",
        type=pathlib.Path,
        help="The entry_points.txt within the dist-info of a PyPI wheel",
    )
    parser.add_argument(
        "out",
        type=pathlib.Path,
        metavar="OUT",
        help="The output file.",
    )
    args = parser.parse_args()

    run(
        entry_points=args.entry_points,
        out=args.out,
        console_script=args.console_script,
    )


if __name__ == "__main__":
    main()
