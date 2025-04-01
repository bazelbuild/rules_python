# Copyright 2022 The Bazel Authors. All rights reserved.
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
"""Implementation of macro-half of py_library rule."""

load(":py_library_rule.bzl", py_library_rule = "py_library")
load(":py_binary_rule.bzl", py_binary_rule = "py_binary")

# The py_library's attributes we don't want to forward to auto-generated
# targets.
_LIBRARY_ONLY_ATTRS = [
    "srcs",
    "deps",
    "data",
    "imports",
]

# A wrapper macro is used to avoid any user-observable changes between a
# rule and macro. It also makes generator_function look as expected.
def py_library(name, **kwargs):
    library_only_attrs = {
        attr: kwargs.pop(attr, None)
        for attr in _LIBRARY_ONLY_ATTRS
    }
    py_library_rule(
        name = name,
        **(library_only_attrs | kwargs)
    )
    py_binary_rule(
        name = "%s.repl" % name,
        srcs = [],
        main_module = "python.bin.repl",
        deps = [
            ":%s" % name,
            "@rules_python//python/bin:repl",
        ],
        **kwargs
    )
