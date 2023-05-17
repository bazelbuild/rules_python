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

import json
import os
import platform
import re
import shutil
import sys
import tempfile
import textwrap
from pathlib import Path
from subprocess import Popen

from rules_python.python.runfiles import runfiles

r = runfiles.Create()


def main(conf_file):
    with open(conf_file) as j:
        config = json.load(j)

    isWindows = platform.system() == "Windows"
    bazelBinary = r.Rlocation(
        os.path.join(
            config["bazelBinaryWorkspace"], "bazel.exe" if isWindows else "bazel"
        )
    )

    workspacePath = config["workspaceRoot"]
    # Canonicalize bazel external/some_repo/foo
    if workspacePath.startswith("external/"):
        workspacePath = ".." + workspacePath[len("external") :]

    with tempfile.TemporaryDirectory(dir=os.environ["TEST_TMPDIR"]) as tmp_homedir:
        home_bazel_rc = Path(tmp_homedir) / ".bazelrc"
        home_bazel_rc.write_text(
            textwrap.dedent(
                """\
                startup --max_idle_secs=1
                common --announce_rc
                """
            )
        )

        with tempfile.TemporaryDirectory(dir=os.environ["TEST_TMPDIR"]) as tmpdir:
            workdir = os.path.join(tmpdir, "wksp")
            print("copying workspace under test %s to %s" % (workspacePath, workdir))
            shutil.copytree(workspacePath, workdir)

            for command in config["bazelCommands"]:
                bazel_args = command.split(" ")
                bazel_args.append(
                    "--override_repository=rules_python=%s/rules_python"
                    % os.environ["TEST_SRCDIR"]
                )
                bazel_args.append(
                    "--override_repository=rules_python_gazelle_plugin=%s/rules_python_gazelle_plugin"
                    % os.environ["TEST_SRCDIR"]
                )

                # TODO: --override_module isn't supported in the current BAZEL_VERSION (5.2.0)
                # This condition and attribute can be removed when bazel is updated for
                # the rest of rules_python.
                if config["bzlmod"]:
                    bazel_args.append(
                        "--override_module=rules_python=%s/rules_python"
                        % os.environ["TEST_SRCDIR"]
                    )
                    bazel_args.append("--enable_bzlmod")

                # Bazel's wrapper script needs this or you get
                # 2020/07/13 21:58:11 could not get the user's cache directory: $HOME is not defined
                os.environ["HOME"] = str(tmp_homedir)

                bazel_args.insert(0, bazelBinary)
                bazel_process = Popen(bazel_args, cwd=workdir)
                bazel_process.wait()
                error = bazel_process.returncode != 0

                if platform.system() == "Windows":
                    # Cleanup any bazel files
                    bazel_process = Popen([bazelBinary, "clean"], cwd=workdir)
                    bazel_process.wait()
                    error |= bazel_process.returncode != 0

                    # Shutdown the bazel instance to avoid issues cleaning up the workspace
                    bazel_process = Popen([bazelBinary, "shutdown"], cwd=workdir)
                    bazel_process.wait()
                    error |= bazel_process.returncode != 0

                if error != 0:
                    # Test failure in Bazel is exit 3
                    # https://github.com/bazelbuild/bazel/blob/486206012a664ecb20bdb196a681efc9a9825049/src/main/java/com/google/devtools/build/lib/util/ExitCode.java#L44
                    sys.exit(3)


if __name__ == "__main__":
    main(sys.argv[1])
