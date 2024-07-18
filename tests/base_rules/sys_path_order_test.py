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

import os.path
import re
import sys
import unittest

# Look for the entries Python adds for finding its standard library:
# pythonX.Y, pythonXY.zip, and pythonX.Y/lib-dynload
# See https://docs.python.org/3/library/sys_path_init.html#sys-path-init
# for details.
_STDLIB_REGEX = r".*python\d[.]\d+$|.*python\d+[.]zip$|.*lib-dynload$|"


# Windows: `{sys.prefix}/Lib/site-packages"
# Others: `
_STDLIB_SITE_PACKAGES_REGEX = r".*(python\d[.]\d+|Lib)/(site|dist)-packages$"


class SysPathOrderTest(unittest.TestCase):
    def test_sys_path_order(self):
        last_stdlib = None
        first_user = None
        first_runtime_site = None
        for i, value in enumerate(sys.path):
            # Normalize windows paths to unix paths
            ##value = value.replace(os.path.sep, "/")
            if value.startswith(sys.prefix):
                if os.path.basename(value).endswith("-packages"):
                    if first_runtime_site is None:
                        first_runtime_site = i
                else:
                    last_stdlib = i
            elif first_user is None:
                first_user = i
            ##if re.match(_STDLIB_REGEX, value):
            ##    last_stdlib = i
            ##elif re.match(_STDLIB_SITE_PACKAGES_REGEX, value):
            ##    if first_runtime_site is None:
            ##        first_runtime_site = i
            ##elif ".runfiles" in value:
            ##    if first_user is None:
            ##        first_user = i
            ##else:
            ##    raise AssertionError(f"Unexpected sys.path format: {value}")

        sys_path_str = "\n".join(f"{i}: {v}" for i, v in enumerate(sys.path))
        if None in (last_stdlib, first_user, first_runtime_site):
            self.fail(
                "Failed to find position for one of:\n"
                + f"{last_stdlib=} {first_user=} {first_runtime_site=}\n"
                + f"for sys.path:\n{sys_path_str}"
            )

        if os.environ["BOOTSTRAP"] == "script":
            self.assertTrue(
                last_stdlib < first_user < first_runtime_site,
                f"Expected {last_stdlib=} < {first_user=} < {first_runtime_site=}\nfor sys.path:\n{sys_path_str}",
            )
        else:
            self.assertTrue(
                first_user < last_stdlib < first_runtime_site,
                f"Expected {first_user=} < {last_stdlib=} < {first_runtime_site=}\nfor sys.path:\n{sys_path_str}",
            )


if __name__ == "__main__":
    unittest.main()
