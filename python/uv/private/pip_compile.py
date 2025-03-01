#!/usr/bin/env python3

import os
import pathlib
import sys

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
    args = sys.argv[1:]
    running_interactively = "BUILD_WORKSPACE_DIRECTORY" in env

    if args[-2] != "--output-file":
        raise ValueError("The last arg should be the output file")

    src_out = args[1] if args[0] == "--src-out" else None

    if running_interactively:
        args[-1] = pathlib.Path(env["BUILD_WORKSPACE_DIRECTORY"]) / args[-1]
    elif src_out:
        args = args[2:]
        out = args[-1]

        src = pathlib.Path(src_out)
        dst = pathlib.Path(out)
        dst.write_text(src.read_text())

    if sys.platform == "win32":
        import subprocess

        completed_process = subprocess.run([uv, *args], env=env)
        sys.exit(completed_process.returncode)
    else:
        os.execvpe(uv, [uv, *args], env=env)


if __name__ == "__main__":
    _run()
