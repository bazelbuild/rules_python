import sys
from difflib import unified_diff
from os import environ
from pathlib import Path


def main():
    src = ""
    dst = ""

    src = Path(src)
    assert src.exists(), f"the {src} file does not exist"

    if "BUILD_WORKSPACE_DIRECTORY" not in environ:
        dst = Path(dst)
        a = dst.read_text() if dst.exists() else "\n"
        b = src.read_text()

        diff = unified_diff(
            a.splitlines(),
            b.splitlines(),
            str(dst),
            str(src),
            lineterm="",
        )
        diff = "\n".join(list(diff))
        print(diff)
        print(
            """\

===============================================================================
The in source file copy is out of date, please run the failed test target with
'bazel run' to fix the error message update the source file copy.
===============================================================================
"""
        )
        return 1 if diff else 0

    print(f"cp <bazel-sandbox>/{src}", file=sys.stderr)
    print(f"    -> <workspace>/{dst}", file=sys.stderr)
    build_workspace = Path(environ["BUILD_WORKSPACE_DIRECTORY"])

    dst = build_workspace / dst
    dst.write_text(src.read_text())
    print("Success!", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
