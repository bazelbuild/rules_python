# Copyright 2020 The Bazel Authors. All rights reserved.
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

load("@rules_python//python:defs.bzl", "py_import", "py_test")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

# Adapt helloworld.egg so it can be depended on as if it were a
# py_library target
py_import(
    name = "py_import",
    # Note: this .egg file can be regenerated using zipper:
    # $ third_party/ijar/zipper Cc \
    #   examples/py_import/helloworld.egg \
    #   examples/py_import/helloworld.py=examples/legacy_pip_import/helloworld/helloworld.py \
    #   examples/__init__.py= \
    #   examples/py_import/__init__.py=
    # TODO: we should construct an egg from local sources, or to make
    # the example more meaningful for users, find an egg on the internet.
    # Also it would help illustrate the rules if the egg has some other
    # dependency, requiring deps here.
    srcs = ["helloworld.egg"],
)

py_test(
    name = "py_import_test",
    srcs = ["py_import_test.py"],
    deps = [":py_import"],
)
