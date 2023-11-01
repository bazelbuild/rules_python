# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import platform
import sys


def main(argv):
    # For the purposes of our pycross testing, we can skip patching on Windows
    # for now. We don't have a great way to do that at the moment.
    if platform.system() == "Windwos":
        print("Applying patches on Windows is not supported at the moment.")
        return

    # On non-Windows systems, delegate to the `patch` tool.
    os.execvp("patch", ["patch"] + sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
