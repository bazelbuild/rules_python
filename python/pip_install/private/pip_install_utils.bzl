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

"""Utilities for `rules_python` pip rules"""

_SRCS_TEMPLATE = """\
\"\"\"A generated file containing all source files used for `@rules_python//python/pip_install:pip_repository.bzl` rules

This file is auto-generated from the `@rules_python//python/pip_install/private:srcs_module.update` target. Please
`bazel run` this target to apply any updates. Note that doing so will discard any local modifications.
"\"\"

# Each source file is tracked as a target so `pip_repository` rules will know to automatically rebuild if any of the
# sources changed.
PIP_INSTALL_PY_SRCS = [
    {srcs}
]
"""

def _src_label(file):
    dir_path, file_name = file.short_path.rsplit("/", 1)

    return "@rules_python//{}:{}".format(
        dir_path,
        file_name,
    )

def _srcs_module_impl(ctx):
    srcs = [_src_label(src) for src in ctx.files.srcs]
    if not srcs:
        fail("`srcs` cannot be empty")
    output = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.write(
        output = output,
        content = _SRCS_TEMPLATE.format(
            srcs = "\n    ".join(["\"{}\",".format(src) for src in srcs]),
        ),
    )

    return DefaultInfo(
        files = depset([output]),
    )

_srcs_module = rule(
    doc = "A rule for writing a list of sources to a templated file",
    implementation = _srcs_module_impl,
    attrs = {
        "srcs": attr.label(
            doc = "A filegroup of source files",
            allow_files = True,
        ),
    },
)

_INSTALLER_TEMPLATE = """\
#!/bin/bash
set -euo pipefail
cp -f "{path}" "${{BUILD_WORKSPACE_DIRECTORY}}/{dest}"
"""

def _srcs_updater_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".sh")
    target_file = ctx.file.input
    dest = ctx.file.dest.short_path

    ctx.actions.write(
        output = output,
        content = _INSTALLER_TEMPLATE.format(
            path = target_file.short_path,
            dest = dest,
        ),
        is_executable = True,
    )

    return DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [target_file]),
        executable = output,
    )

_srcs_updater = rule(
    doc = "A rule for writing a `srcs.bzl` file back to the repository",
    implementation = _srcs_updater_impl,
    attrs = {
        "dest": attr.label(
            doc = "The target file to write the new `input` to.",
            allow_single_file = ["srcs.bzl"],
            mandatory = True,
        ),
        "input": attr.label(
            doc = "The file to write back to the repository",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    executable = True,
)

def srcs_module(name, dest, **kwargs):
    """A helper rule to ensure `pip_repository` rules are always up to date

    Args:
        name (str): The name of the sources module
        dest (str): The filename the module should be written as in the current package.
        **kwargs (dict): Additional keyword arguments
    """
    tags = kwargs.pop("tags", [])

    _srcs_module(
        name = name,
        tags = tags,
        **kwargs
    )

    _srcs_updater(
        name = name + ".update",
        input = name,
        dest = dest,
        tags = tags,
    )
