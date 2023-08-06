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
import requests


def cognitojwt_version() -> str:
    return pkg_resources.require("cognitojwt")[0].version

def requests_version() -> str:
    return requests.__version__

def main(argv):
    print(f"cognitojwt version: {cognitojwt_version()}")
    print(f"requests version: {requests_version()}")

if __name__ == "__main__":
    sys.exit(main(sys.argv))
