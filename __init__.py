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

# This file gets imported when both of these are true:
#  * bzlmod is disabled
#  * `import rules_python` happens for the first time
# This is because the runfiles root is before rules_python/src-d in sys.path,
# and the repo directory name is "rules_python", thus making it importable.
# To work around this case, import the src-d code as a normal submodule,
# then patch up imports to make it look like nothing happened.
#
# When bzlmod is enabled, the directory name changes (it isn't importable),
# the src-d directory is used instead, and this file is never executed.
rules_python = importlib.import_module("rules_python.src-d.rules_python")

# The module was imported as another name, so fix that up here.
rules_python.__name__ = "rules_python"
rules_python.__package__ = "rules_python"
if rules_python.__spec__ is not None:
    rules_python.__spec__.name = "rules_python"

sys.modules["rules_python"] = rules_python
