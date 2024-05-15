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

"""This module contains the Gazelle runtime dependencies for the Python extension.
"""

load("@bazel_skylib//lib:modules.bzl", "modules")
load(":deps.bzl", "python_stdlib_list_deps")

GAZELLE_PYTHON_RUNTIME_DEPS = [
]

non_module_deps = modules.as_extension(
    python_stdlib_list_deps,
    doc = "This extension registers python stdlib list dependencies.",
)
