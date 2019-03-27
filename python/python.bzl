# Copyright 2017-2019 The Bazel Authors. All rights reserved.
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

load("@bazel_skylib//lib:paths.bzl", "paths")

def py_library(*args, **kwargs):
    """See the Bazel core py_library documentation.

    [available here](
    https://docs.bazel.build/versions/master/be/python.html#py_library).
    """
    native.py_library(*args, **kwargs)

def py_binary(*args, **kwargs):
    """See the Bazel core py_binary documentation.

    [available here](
    https://docs.bazel.build/versions/master/be/python.html#py_binary).
    """
    native.py_binary(*args, **kwargs)

def py_test(*args, **kwargs):
    """See the Bazel core py_test documentation.

    [available here](
    https://docs.bazel.build/versions/master/be/python.html#py_test).
    """
    native.py_test(*args, **kwargs)

def _py_import_impl(ctx):
    # See https://github.com/bazelbuild/bazel/blob/0.24.0/src/main/java/com/google/devtools/build/lib/bazel/rules/python/BazelPythonSemantics.java#L104 .
    import_paths = [
        paths.normalize(paths.join(ctx.workspace_name, x.short_path))
        for x in ctx.files.srcs
    ]

    return [
        DefaultInfo(
            default_runfiles = ctx.runfiles(ctx.files.srcs),
        ),
        PyInfo(
            transitive_sources = depset(),
            imports = depset(direct = import_paths),
        ),
    ]

py_import = rule(
    doc = "This rule allows the use of Python eggs as libraries for " +
          "`py_library` and `py_binary` rules.",
    implementation = _py_import_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "The list of Python eggs provided to Python targets " +
                  "that depend on this target.",
            allow_files = [".egg"],
        ),
    },
)
