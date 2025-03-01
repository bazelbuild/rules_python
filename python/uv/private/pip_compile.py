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

    src_out = args[1] if args[0] == "--src-out" else None
    if src_out:
        args = args[2:]

    if args[0] != "--output-file":
        raise ValueError(
            f"The first arg should be to declare the output file, got:\n{args}"
        )
    else:
        out = args[1]

    if running_interactively:
        args[1] = pathlib.Path(env["BUILD_WORKSPACE_DIRECTORY"]) / out
    elif src_out:
        src = pathlib.Path(src_out)
        dst = pathlib.Path(out)
        dst.write_text(src.read_text())

    uv_args = ["pip", "compile"] + args

    if sys.platform == "win32":
        import subprocess

        completed_process = subprocess.run([uv, *uv_args], env=env)
        sys.exit(completed_process.returncode)
    else:
        os.execvpe(uv, [uv, *uv_args], env=env)


if __name__ == "__main__":
    _run()
