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

"Module extension that finds the current toolchain Python binary and creates a symlink to it."

load("@pythons_hub//:interpreters.bzl", "INTERPRETER_LABELS")

def _interpreter_impl(mctx):
    for mod in mctx.modules:
        for install_attr in mod.tags.install:
            _interpreter_repo(
                name = install_attr.name,
                python_name = install_attr.python_name,
            )

interpreter = module_extension(
    doc = """\
This extension is used to expose the underlying platform-specific
interpreter registered as a toolchain. It is used by users to get
a label to the interpreter for use with pip.parse
in the MODULES.bazel file.
""",
    implementation = _interpreter_impl,
    tag_classes = {
        "install": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name of the interpreter, we use this name to set the interpreter for pip.parse",
                    mandatory = True,
                ),
                "python_name": attr.string(
                    doc = "The name set in the previous python.toolchain call.",
                    mandatory = True,
                ),
            },
        ),
    },
)

def _interpreter_repo_impl(rctx):
    rctx.file("BUILD.bazel", "")

    actual_interpreter_label = INTERPRETER_LABELS.get(rctx.attr.python_name)
    if actual_interpreter_label == None:
        fail("Unable to find interpreter with name '{}'".format(rctx.attr.python_name))

    rctx.symlink(actual_interpreter_label, "python")

_interpreter_repo = repository_rule(
    doc = """\
Load the INTERPRETER_LABELS map. This map contain of all of the Python binaries
by name and a label the points to the interpreter binary. The
binaries are downloaded as part of the python toolchain setup.
The rule finds the label and creates a symlink named "python" to that
label. This symlink is then used by pip.
""",
    implementation = _interpreter_repo_impl,
    attrs = {
        "python_name": attr.string(
            mandatory = True,
            doc = "Name of the Python toolchain",
        ),
    },
)
