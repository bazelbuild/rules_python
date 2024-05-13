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
"""
This file contains the non_module_deps rule.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

def non_module_deps_impl(_):
    http_file(
        name = "python_stdlib_list",
        sha256 = "3c1dbf991b17178d6ed3772f4fa8f64302feaf9c3385fef328a0c7ab736a79b1",
        url = "https://raw.githubusercontent.com/pypi/stdlib-list/8cbc2067a4a0f9eee57fb541e4cd7727724b7db4/stdlib_list/lists/3.11.txt",
        downloaded_file_path = "3.11.txt",  # TODO: auto version
    )

non_module_deps = module_extension(implementation = non_module_deps_impl)
