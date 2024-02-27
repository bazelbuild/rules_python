import runpy
import sys
from pathlib import Path

from python.runfiles import runfiles

RUNFILES = runfiles.Create()
RUNFILES_DIR = Path(RUNFILES.EnvVars()["RUNFILES_DIR"])
MAIN = RUNFILES_DIR / "%MAIN_REPO%/%MAIN_SHORT_PATH%"

IMPORTS = %IMPORTS%

# Work around sys.path[0] escaping the sandbox by deleting it.
# See https://github.com/bazelbuild/rules_python/issues/382 for more info.
# TODO(phil): How do we distinguish between safe-path Python and non-safe-path
# Python? I.e. how do we know if sys.path[0] should be deleted or not?
del sys.path[0]

sys.path[0:0] = [str(RUNFILES_DIR / path) for path in IMPORTS]

runpy.run_path(str(MAIN), run_name="__main__")
