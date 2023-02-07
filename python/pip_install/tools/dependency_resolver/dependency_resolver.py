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

"Set defaults for the pip-compile command to run it under Bazel"

import os
import re
import sys
from pathlib import Path
from shutil import copyfile

from piptools.scripts.compile import cli


def _select_golden_requirements_file(
    requirements_txt, requirements_linux, requirements_darwin, requirements_windows
):
    """Switch the golden requirements file, used to validate if updates are needed,
    to a specified platform specific one.  Fallback on the platform independent one.
    """

    plat = sys.platform
    if plat == "linux" and requirements_linux is not None:
        return requirements_linux
    elif plat == "darwin" and requirements_darwin is not None:
        return requirements_darwin
    elif plat == "win32" and requirements_windows is not None:
        return requirements_windows
    else:
        return requirements_txt


def _fix_up_requirements_in_path(absolute_prefix, output_file):
    """Fix up references to the input file inside of the generated requirements file.

    We don't want fully resolved, absolute paths in the generated requirements file.
    The paths could differ for every invocation. Replace them with a predictable path.
    """
    output_file = Path(output_file)
    contents = output_file.read_text()
    contents = contents.replace(absolute_prefix, "")
    contents = re.sub(r"\\(?!(\n|\r\n))", "/", contents)
    output_file.write_text(contents)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(
            "Expected at least two arguments: requirements_in requirements_out",
            file=sys.stderr,
        )
        sys.exit(1)

    parse_str_none = lambda s: None if s == "None" else s

    requirements_in = sys.argv.pop(1)
    requirements_txt = sys.argv.pop(1)
    requirements_linux = parse_str_none(sys.argv.pop(1))
    requirements_darwin = parse_str_none(sys.argv.pop(1))
    requirements_windows = parse_str_none(sys.argv.pop(1))
    update_target_label = sys.argv.pop(1)

    # The requirements_in file could be generated, so we will need to remove the
    # absolute prefixes in the locked requirements output file.
    requirements_in_path = Path(requirements_in)
    resolved_requirements_in = str(requirements_in_path.resolve())
    absolute_prefix = resolved_requirements_in[: -len(str(requirements_in_path))]

    # Before loading click, set the locale for its parser.
    # If it leaks through to the system setting, it may fail:
    # RuntimeError: Click will abort further execution because Python 3 was configured to use ASCII
    # as encoding for the environment. Consult https://click.palletsprojects.com/python3/ for
    # mitigation steps.
    os.environ["LC_ALL"] = "C.UTF-8"
    os.environ["LANG"] = "C.UTF-8"

    UPDATE = True
    # Detect if we are running under `bazel test`
    if "TEST_TMPDIR" in os.environ:
        UPDATE = False
        # pip-compile wants the cache files to be writeable, but if we point
        # to the real user cache, Bazel sandboxing makes the file read-only
        # and we fail.
        # In theory this makes the test more hermetic as well.
        sys.argv.append("--cache-dir")
        sys.argv.append(os.environ["TEST_TMPDIR"])
        # Make a copy for pip-compile to read and mutate
        requirements_out = os.path.join(
            os.environ["TEST_TMPDIR"], os.path.basename(requirements_txt) + ".out"
        )
        copyfile(requirements_txt, requirements_out)

    elif "BUILD_WORKSPACE_DIRECTORY" in os.environ:
        # This value, populated when running under `bazel run`, is a path to the
        # "root of the workspace where the build was run."
        # This matches up with the values passed in via the macro using the 'rootpath' Make variable,
        # which for source files provides a path "relative to your workspace root."
        #
        # Changing to the WORKSPACE root avoids 'file not found' errors when the `.update` target is run
        # from different directories within the WORKSPACE.
        os.chdir(os.environ["BUILD_WORKSPACE_DIRECTORY"])
    else:
        err_msg = (
            "Expected to find BUILD_WORKSPACE_DIRECTORY (running under `bazel run`) or "
            "TEST_TMPDIR (running under `bazel test`) in environment."
        )
        print(
            err_msg,
            file=sys.stderr,
        )
        sys.exit(1)

    update_command = os.getenv("CUSTOM_COMPILE_COMMAND") or "bazel run %s" % (
        update_target_label,
    )

    os.environ["CUSTOM_COMPILE_COMMAND"] = update_command
    os.environ["PIP_CONFIG_FILE"] = os.getenv("PIP_CONFIG_FILE") or os.devnull

    sys.argv.append("--generate-hashes")
    sys.argv.append("--output-file")
    sys.argv.append(requirements_txt if UPDATE else requirements_out)
    sys.argv.append(
        requirements_in if requirements_in_path.exists() else resolved_requirements_in
    )

    if UPDATE:
        print("Updating " + requirements_txt)
        try:
            cli()
        except SystemExit as e:
            if e.code == 0:
                _fix_up_requirements_in_path(absolute_prefix, requirements_txt)
            raise
    else:
        # cli will exit(0) on success
        try:
            print("Checking " + requirements_txt)
            cli()
            print("cli() should exit", file=sys.stderr)
            sys.exit(1)
        except SystemExit as e:
            if e.code == 2:
                print(
                    "pip-compile exited with code 2. This means that pip-compile found "
                    "incompatible requirements or could not find a version that matches "
                    f"the install requirement in {requirements_in}.",
                    file=sys.stderr,
                )
                sys.exit(1)
            elif e.code == 0:
                _fix_up_requirements_in_path(absolute_prefix, requirements_out)
                golden_filename = _select_golden_requirements_file(
                    requirements_txt,
                    requirements_linux,
                    requirements_darwin,
                    requirements_windows,
                )
                golden = open(golden_filename).readlines()
                out = open(requirements_out).readlines()
                if golden != out:
                    import difflib

                    print("".join(difflib.unified_diff(golden, out)), file=sys.stderr)
                    print(
                        "Lock file out of date. Run '"
                        + update_command
                        + "' to update.",
                        file=sys.stderr,
                    )
                    sys.exit(1)
                sys.exit(0)
            else:
                print(
                    f"pip-compile unexpectedly exited with code {e.code}.",
                    file=sys.stderr,
                )
                sys.exit(1)
