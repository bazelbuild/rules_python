# Copyright 2024 The Bazel Authors. All rights reserved.
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
import importlib

# Normally this file should never be imported; the sys.path will have
# src-d/rules_python earlier in the import path. But, ChromeOS has a hack in
# their toolchain's sitecustomize.py that causes the rules_python/__init__.py
# file to be ignored, and thus the module patching it does doesn't happen. To
# work around that, perform equivalent module patching here. See
# tests/integration/importing_runfiles/import_faked_rules_python_test.py for
# details.
rules_python_python = importlib.import_module("rules_python.src-d.rules_python.python")

rules_python_python.__name__ = "rules_python.python"
rules_python_python.__package__ = "rules_python.python"
rules_python_python.__spec__.name = "rules_python.python"
rules_python_python.__spec__.name = "rules_python.python"

sys.modules["rules_python.python"] = rules_python_python
