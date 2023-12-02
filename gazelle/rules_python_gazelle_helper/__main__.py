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

# parse.py is a long-living program that communicates over STDIN and STDOUT.
# STDIN receives parse requests, one per line. It outputs the parsed modules and
# comments from all the files from each request.

import sys

# NOTE @aignas 2023-12-02: Use absolute imports with respect to WORKSPACE root.
# With Python versions other than 3.11 doing import parse import std_modules
# works fine, but with 3.11 we need to use absolute import paths, which could be
# due to differences in the bootstrap template in 3.11, which is more strict.
#
# We are also using a unique name to avoid any name clashes
from rules_python_gazelle_helper import parse, std_modules

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Please provide subcommand, either print or std_modules")
    if sys.argv[1] == "parse":
        sys.exit(parse.main(sys.stdin, sys.stdout))
    elif sys.argv[1] == "std_modules":
        sys.exit(std_modules.main(sys.stdin, sys.stdout))
    else:
        sys.exit("Unknown subcommand: " + sys.argv[1])
