# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""This package contains two sets of rules:

    1) the "core" Python rules, which were historically bundled with Bazel and
       are now either re-exported or copied into this repository; and

    2) the packaging rules, which were historically simply known as
       rules_python.

In an ideal renaming, we'd move the packaging rules to a different package so
that @rules_python//python is only concerned with the core rules.
"""

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

# Core rules.
exports_files([
    "defs.bzl",
    "python.bzl",  # Deprecated, please use defs.bzl
])

# Packaging rules, unrelated to the core rules.
exports_files([
    "pip.bzl",
    "whl.bzl",
])
