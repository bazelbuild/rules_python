from os import environ
from pathlib import Path
from sys import stderr

src = Path(environ["REQUIREMENTS_FILE"])
assert src.exists(), f"the {src} file does not exist"
dst = ""

print(f"cp <bazel-sandbox>/{src}\\n    -> <workspace>/{dst}", file=stderr)
build_workspace = Path(environ["BUILD_WORKSPACE_DIRECTORY"])

dst = build_workspace / dst
dst.write_text(src.read_text())
print("Success!", file=stderr)
