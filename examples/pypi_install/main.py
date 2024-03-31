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

import sys

import pkg_resources

import pkg_a.foo

def pkg_a_version() -> str:
    return pkg_resources.require("pkg-a")[0].version

def pkg_a_function() -> str:
    return pkg_a.foo.original_function()

def main(argv):
    print(f"pkg_a version: {pkg_a_version()}")
    print(f"pkg_a function: {pkg_a_function()}")

if __name__ == "__main__":
    sys.exit(main(sys.argv))
