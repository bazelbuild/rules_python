import os
import sys

expected = os.getenv("VERSION_CHECK")
current = f"{sys.version_info.major}.{sys.version_info.minor}"

if current != expected:
    print(f"expected version '{expected}' is different than returned '{current}'")
    sys.exit(1)
