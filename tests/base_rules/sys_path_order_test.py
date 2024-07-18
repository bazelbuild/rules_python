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

        # Classify paths into the three different types we care about: stdlib,
        # user dependency, or the runtime's site-package's directory.
        # Because they often share common prefixes and vary subtly between
        # platforms, we do this is two passes: first category, then compute
        # the indexes. This is just so debugging is easier, especially
        # for platforms a dev doesn't have.
        categorized_paths = []
        for i, value in enumerate(sys.path):
            # Normalize windows paths to unix paths
            ##value = value.replace(os.path.sep, "/")
            if value == sys.prefix:
                category = "user"
            elif value.startswith(sys.prefix):
                if os.path.basename(value).endswith("-packages"):
                    category = "runtime-site"
                else:
                    category = "stdlib"
            else:
                category = "user"

            categorized_paths.append((category, value))

        for i, (category, _) in categorized_paths:
            if category == "stdlib":
                last_stdlib = i
            elif category == "runtime-site":
                if first_runtime_site is None:
                    first_runtime_site = i
            elif category == "user":
                if first_user is None:
                    first_user = i

        sys_path_str = "\n".join(
            f"{i}: ({category}) {value}"
            for i, (category, value) in enumerate(categorized_paths)
        )
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
