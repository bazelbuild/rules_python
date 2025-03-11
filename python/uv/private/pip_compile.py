#!/usr/bin/env python3

import argparse
import os
import sys
from pathlib import Path


def _run() -> None:
    uv_path = ""
    if not uv_path:
        from python import runfiles

        rfiles = runfiles.Create()
        uv_path = rfiles.Rlocation("_main/python/uv/current_toolchain/uv")

    if not uv_path:
        raise RuntimeError("cannot find uv: {}".format(uv_path))

    uv = os.fsdecode(uv_path)
    env = os.environ.copy()

    # TODO @aignas 2025-03-11: this does not work when we try to pass extra args via bazel run
    # The best way is to do a template expansion.

    params = Path(f"{sys.argv[0]}.params.txt")
    assert params.exists(), f"{params} does not exist"
    sys_args = params.read_text().strip().split("\n")

    # Let `uv` know that it was spawned by this Python interpreter
    env["UV_INTERNAL__PARENT_INTERPRETER"] = sys.executable
    args = []
    src_out = sys_args[1] if sys_args[0] == "--src-out" else None
    if src_out:
        sys_args = sys_args[2:]

    if sys_args[0] != "--output-file":
        raise ValueError(
            f"The first arg should be to declare the output file, got:\n{sys_args}"
        )
    else:
        out = sys_args[1]

    # this is set under bazel run
    workspace = env.get("BUILD_WORKSPACE_DIRECTORY")
    if workspace:
        dst = Path(workspace) / out
    elif src_out:
        src = Path(src_out)
        dst = Path(out)
        import shutil

        shutil.copy(src, dst)
    sys_args[1] = str(dst)

    uv_args = ["pip", "compile"] + args + sys_args + uv_args

    if sys.platform == "win32":
        import subprocess

        completed_process = subprocess.run([uv, *uv_args], env=env)
        sys.exit(completed_process.returncode)
    else:
        os.execvpe(uv, [uv, *uv_args], env=env)


if __name__ == "__main__":
    _run()
