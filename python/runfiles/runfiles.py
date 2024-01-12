# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys

# Normally this file should never be imported because either (a) sys.path will
# have src-d earlier in the import search path, or (b) the root-level
# __init__.py will redirect further imports to src-d.
#
# Unfortunately, this file is still importable in some cases:
# 1. sys.path=[rules_python/, rules_python/src-d] and `import python.runfiles`
#    This is the standard u
# 2. sys.path
#
# 1. import python.runfiles with
#    sys.path=[$runfilesRoot/rules_python, $runfilesRoot/rules_python/src-d]
#    This is a deprecated way used for early compatibility with bzlmod before
#    `import rules_python` worked with bzlmod enabled (issue #1679)
# 2. import python with
#    sys.path=[$runfilesRoot/rules_python]
#    This is the state of things when our repository rules run because they
#    run before the regular build phase.
# 3. import rules_python.python.runfiles
#    sys.path=[$runfilesRoot, $runfilesRoot/rules_python/src-d]
#    BUT the top-level rules_python/__init__.py file is *ignored*.
#    This happens because of a hack in the ChromeOS toolchain's sitecustomize.py
#    that causes the rules_python/__init__.py file to be ignored, and thus the
#    module patching it does doesn't happen. To work around that, perform
#    equivalent module patching here. See
#    tests/integration/importing_runfiles/import_faked_rules_python_test.py for
#    details.

if __name__ == "python.runfiles.runfiles":
    # Case (1) or (2) from above
    from rules_python.python.runfiles import runfiles as canonical_runfiles
    sys.modules[__name__] = canonical_runfiles
elif __name__ == "rules_python.python.runfiles.runfiles":
    # Case (3) from above
    import importlib
    canonical_runfiles = importlib.import_module("rules_python.src-d.rules_python.python")
    sys.modules[__name__] = canonical_runfiles
else:
    raise ImportError("how did we get here?")
