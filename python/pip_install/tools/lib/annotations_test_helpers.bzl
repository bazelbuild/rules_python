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

"""Helper macros and rules for testing the `annotations` module of `tools`"""

load("//python:pip.bzl", _package_annotation = "package_annotation")

package_annotation = _package_annotation

def _package_annotations_file_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".annotations.json")

    annotations = {package: json.decode(data) for (package, data) in ctx.attr.annotations.items()}
    ctx.actions.write(
        output = output,
        content = json.encode_indent(annotations, indent = " " * 4),
    )

    return DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )

package_annotations_file = rule(
    implementation = _package_annotations_file_impl,
    doc = (
        "Consumes `package_annotation` definitions in the same way " +
        "`pip_repository` rules do to produce an annotations file."
    ),
    attrs = {
        "annotations": attr.string_dict(
            doc = "See `@rules_python//python:pip.bzl%package_annotation",
            mandatory = True,
        ),
    },
)
