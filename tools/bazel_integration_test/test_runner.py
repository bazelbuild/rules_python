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
