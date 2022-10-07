import os
import sys

import libs.my_lib as my_lib

sanitized_version_check = os.getenv("VERSION_CHECK").replace(".", "_")

expected = (
    f"../pypi_{sanitized_version_check}_websockets/site-packages/websockets/__init__.py"
)
current = my_lib.websockets_relative_path()

if expected != current:
    print(f"expected '{expected}' is different than returned '{current}'")
    sys.exit(1)
