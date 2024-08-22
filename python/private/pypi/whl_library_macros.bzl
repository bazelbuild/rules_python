# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Generate targets for the whl_library macro."""

load("//python:py_library.bzl", "py_library")
load(":labels.bzl", "DATA_LABEL", "DIST_INFO_LABEL")

def dist_info_filegroup(
        *,
        name = DIST_INFO_LABEL,
        visibility = ["//visibility:public"],
        native = native):
    """Generate the dist-info target.

    Args:
        name: The name for the `dist_info` target.
        visibility: The visibility of the target.
        native: The native struct for unit testing.
    """
    native.filegroup(
        name = name,
        srcs = native.glob(["site-packages/*.dist-info/**"], allow_empty = True),
        visibility = visibility,
    )

def data_filegroup(
        *,
        name = DATA_LABEL,
        visibility = ["//visibility:public"],
        native = native):
    """Generate the data target.

    Args:
        name: The name for the `data` target.
        visibility: The visibility of the target.
        native: The native struct for unit testing.
    """
    native.filegroup(
        name = name,
        srcs = native.glob(["data/**"], allow_empty = True),
        visibility = visibility,
    )

def whl_file(
        *,
        name,
        deps,
        srcs,
        visibility = [],
        native = native):
    """Generate the whl target.

    Args:
        name: None, unused.
        deps: The whl deps.
        srcs: The list of whl sources.
        visibility: The visibility passed to the whl target in order
            to group dependencies.
        native: The native struct for unit testing.
    """
    native.filegroup(
        name = name,
        srcs = srcs,
        data = deps,
        visibility = visibility,
    )

def whl_library(
        *,
        name,
        data,
        deps,
        srcs,
        tags = [],
        visibility = [],
        py_library = py_library,
        native = native):
    """Generate the targets that are exposed by an extracted whl library.

    Args:
        name: the name of the library target.
        data: The py_library data.
        deps: The py_library dependencies.
        srcs: The python srcs.
        tags: The tags set to the py_library target to force rebuilding when
            the version of the dependencies changes.
        visibility: The visibility passed to the whl and py_library targets in order
            to group dependencies.
        py_library: The py_library rule to use for defining the targets.
        native: The native struct for unit testing.
    """
    py_library(
        name = name,
        srcs = srcs,
        data = data,
        # This makes this directory a top-level in the python import
        # search path for anything that depends on this.
        imports = ["site-packages"],
        deps = deps,
        tags = tags,
        visibility = visibility,
    )
