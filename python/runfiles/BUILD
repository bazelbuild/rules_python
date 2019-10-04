# Copyright 2019 The Bazel Authors. All rights reserved.
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


# We'd like to alias the runfiles target @bazel_tools//tools/python/runfiles.
# However, we need its source file to exist in the runfiles tree under this
# repo's name, so that it can be imported as
#
#     from rules_python.python.runfiles import runfiles
#
# in user code. This requires either adding a symlink to runfiles or copying
# the file with an action.
#
# Both solutions are made more difficult by the fact that runfiles.py is not
# directly exported by its package. We could try to get a handle on its File
# object by unpacking the runfiles target's providers, but this seems hacky
# and is probably more effort than it's worth. Also, it's not trivial to copy
# files in a cross-platform (i.e. Windows-friendly) way.
#
# So instead, we just vendor in runfiles.py here.

load("//python:defs.bzl", "py_library")

filegroup(
    name = "distribution",
    srcs = glob(["**"]),
    visibility = ["//python:__pkg__"],
)

py_library(
    name = "runfiles",
    srcs = ["runfiles.py"],
    visibility = ["//visibility:public"],
)
