import os
import subprocess
import sys

process = subprocess.run(
    [os.getenv("SUBPROCESS_VERSION_PY_BINARY")],
    stdout=subprocess.PIPE,
    universal_newlines=True,
)

subprocess_current = process.stdout.strip()
subprocess_expected = os.getenv("SUBPROCESS_VERSION_CHECK")

if subprocess_current != subprocess_expected:
    print(
        f"expected subprocess version '{subprocess_expected}' is different than returned '{subprocess_current}'"
    )
    sys.exit(1)

expected = os.getenv("VERSION_CHECK")
current = f"{sys.version_info.major}.{sys.version_info.minor}"

if current != expected:
    print(f"expected version '{expected}' is different than returned '{current}'")
    sys.exit(1)
