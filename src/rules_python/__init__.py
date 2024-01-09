import sys

# Make it so "import python.runfiles" and "import rules_python.python.runfiles"
# both refer to the same object. This avoids importing
# the same code twice under different names.
import python
sys.modules["rules_python.python"] = python

