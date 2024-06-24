# Copyright 2024 The Bazel Authors. All rights reserved.
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

"Rule for locking third-party dependencies with uv."

def _uv_pip_compile(ctx):
    info = ctx.toolchains["//python:uv_toolchain_type"].uvtoolchaininfo
    uv = info.binary

    python = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"].py3_runtime.interpreter
    dependencies_file = ctx.file.dependencies_file

    args = ctx.actions.args()
    args.add("pip")
    args.add("compile")

    # uv will use this python for operations where it needs to execute python code. See: UV_PYTHON and https://github.com/astral-sh/uv?tab=readme-ov-file#installing-into-arbitrary-python-environments
    args.add("--python", python)
    args.add("--python-platform", "windows")
    args.add("--python-version", "3.9")
    args.add("--no-strip-extras")
    args.add("--generate-hashes")
    requirements_out = ctx.actions.declare_file(ctx.label.name + ".requirements.out")
    args.add("--output-file", requirements_out)
    args.add(dependencies_file)

    ctx.actions.run(
        executable = uv,
        arguments = [args],
        inputs = [dependencies_file],
        outputs = [requirements_out],
        tools = [python],
    )

    return [DefaultInfo(
        files = depset([requirements_out]),
    )]

uv_pip_compile = rule(
    implementation = _uv_pip_compile,
    attrs = {
        "constraints_file": attr.label(allow_single_file = True),
        "dependencies_file": attr.label(allow_single_file = True),
        "overrides_file": attr.label(allow_single_file = True),
    },
    toolchains = [
        "@bazel_tools//tools/python:toolchain_type",
        "//python:uv_toolchain_type",
    ],
)
