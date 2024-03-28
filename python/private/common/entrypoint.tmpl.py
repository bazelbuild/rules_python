import runpy
import sys
from pathlib import Path

# TODO(phil): Migrate runfiles detection from
# python/private/python_bootstrap_template.txt into here.
from python.runfiles import runfiles

RUNFILES = runfiles.Create()
RUNFILES_DIR = Path(RUNFILES.EnvVars()["RUNFILES_DIR"])
MAIN = RUNFILES_DIR / "%MAIN_REPO%/%MAIN_SHORT_PATH%"

IMPORTS = %IMPORTS%

# We add the root of each repository with external Python dependencies to the
# import search path.
# Can we get rid of this now that bzlmod mangles the repository names?
MODULE_IMPORTS = [
    Path(path).parts[0]
    for path in IMPORTS
]

def Deduplicate(items):
  """Efficiently filter out duplicates, keeping the first element only."""
  seen = set()
  for it in items:
      if it not in seen:
          seen.add(it)
          yield it

# Work around sys.path[0] escaping the sandbox by deleting it.
# See https://github.com/bazelbuild/rules_python/issues/382 for more info.
if getattr(sys.flags, "safe_path", False):
    # We are running on Python 3.11 and we don't need this workaround
    pass
elif ".runfiles" not in sys.path[0]:
    sys.path = sys.path[1:]

sys.path[0:0] = list(Deduplicate([
    # The top of the runfiles tree always should be first in the search path.
    # Can we get rid of this now that bzlmod mangles the repository names?
    str(RUNFILES_DIR),
] + MODULE_IMPORTS + [
    # Inject the import paths for all the bazel-managed packages so that they are
    # searched before standard library paths.
    str(RUNFILES_DIR / path) for path in IMPORTS
]))

runpy.run_path(str(MAIN), run_name="__main__")
