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

import parse
import std_modules

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Please provide subcommand, either print or std_modules")
    if sys.argv[1] == "parse":
        sys.exit(parse.main(sys.stdin, sys.stdout))
    elif sys.argv[1] == "std_modules":
        sys.exit(std_modules.main(sys.stdin, sys.stdout))
    else:
        sys.exit("Unknown subcommand: " + sys.argv[1])
