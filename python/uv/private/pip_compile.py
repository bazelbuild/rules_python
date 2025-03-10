#!/usr/bin/env python3

import os
import sys
from pathlib import Path

from python import runfiles


def _run() -> None:
    rfiles = runfiles.Create()
    uv_path = rfiles.Rlocation("_main/python/uv/current_toolchain/uv")
    if not uv_path:
        raise RuntimeError("cannot find uv: {}".format(uv_path))

    uv = os.fsdecode(uv_path)
    env = os.environ.copy()

    # Let `uv` know that it was spawned by this Python interpreter
    env["UV_INTERNAL__PARENT_INTERPRETER"] = sys.executable
    args = []
    sys_args = sys.argv[1:]

    src_out = sys_args[1] if sys_args[0] == "--src-out" else None
    if src_out:
        sys_args = sys_args[2:]

    if sys_args[0] != "--output-file":
        raise ValueError(
            f"The first arg should be to declare the output file, got:\n{sys_args}"
        )
    else:
        out = sys_args[1]

    srcs = sys_args[2:]

    # this is set under bazel run
    workspace = env.get("BUILD_WORKSPACE_DIRECTORY")
    if workspace:
        dst = Path(workspace) / out
    elif src_out:
        src = Path(src_out)
        dst = Path(out)
        import shutil

        shutil.copy(src, dst)

    uv_args = ["pip", "compile"] + args + srcs + ["--output-file", str(dst)]

    if sys.platform == "win32":
        import subprocess

        completed_process = subprocess.run([uv, *uv_args], env=env)
        sys.exit(completed_process.returncode)
    else:
        os.execvpe(uv, [uv, *uv_args], env=env)


if __name__ == "__main__":
    _run()
