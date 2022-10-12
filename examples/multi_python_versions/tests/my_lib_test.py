import os
import sys

import libs.my_lib as my_lib

sanitized_version_check = f"{sys.version_info.major}_{sys.version_info.minor}"

if not my_lib.websockets_is_for_python_version(sanitized_version_check):
    print("expected package for Python version is different than returned")
    sys.exit(1)
