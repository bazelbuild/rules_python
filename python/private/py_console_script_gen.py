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

# If we create a `py_console_script_binary` in the main workspace, then the first entry in the `sys.path` will allow
# the Python scripts to load things from outside the `.runfiles` directory. This means that programs like `pylint`
# and `flake8` get confused trying to load from `pylint` when the `py_console_script_binary` is named `pylint`, hence
# we remove the first entry point for this reason.
#
# This would not happen if we created an console_script binary in the root of an external repository, e.g.
# `@pypi_pylint//` because that path is treated differently.

_TEMPLATE = """\
import sys

# See @rules_python//python/private:py_console_script_gen.py for explanation
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
