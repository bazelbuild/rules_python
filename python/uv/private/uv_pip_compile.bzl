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

load("//python/private:toolchain_types.bzl", "TARGET_TOOLCHAIN_TYPE")
load("//python/uv/private:toolchain_types.bzl", "UV_TOOLCHAIN_TYPE")

script_template = """\
{uv} pip compile \
--python {python} \
--python-platform windows \
--python-version 3.9 \
--no-strip-extras \
--generate-hashes \
--output-file - \
{dependencies_file}
"""

def _uv_pip_compile(ctx):
    info = ctx.toolchains[UV_TOOLCHAIN_TYPE].uv_toolchain_info
    uv = info.uv.files.to_list()[0]

    python = ctx.toolchains[TARGET_TOOLCHAIN_TYPE].py3_runtime.interpreter
    dependencies_file = ctx.file.dependencies_file

    # Option 1: Build action option.
    # Not really appropriate, but it executes.

    # args = ctx.actions.args()
    # args.add("pip")
    # args.add("compile")

    # uv will use this python for operations where it needs to execute python code. See: UV_PYTHON and https://github.com/astral-sh/uv?tab=readme-ov-file#installing-into-arbitrary-python-environments
    # args.add("--python", python)
    # args.add("--python-platform", "windows")
    # args.add("--python-version", "3.9")
    # args.add("--no-strip-extras")
    # args.add("--generate-hashes")
    #requirements_out = ctx.actions.declare_file(ctx.label.name + ".requirements.out")
    # args.add("--output-file", requirements_out)
    # args.add(dependencies_file)

    # ctx.actions.run(
    #     executable = uv,
    #     arguments = [args],
    #     inputs = [dependencies_file],
    #     outputs = [requirements_out],
    #     tools = [python],
    # )

    # Option 2: Run action option.
    # Works to exec uv --version, but will need rest of arguments plumbed through.

    # executable = ctx.actions.declare_file("%s-uv" % ctx.label.name)
    # ctx.actions.symlink(
    #     is_executable = True,
    #     output = executable,
    #     target_file = uv,
    # )

    # Option 3: Run action option.
    # Works to exec uv with some (but not all) arguments plumbed through. Output to a directory of the resolved output needs to be done.
    executable = ctx.actions.declare_file("{name}-{uv_name}".format(
        name = ctx.label.name,
        uv_name = uv.basename,
    ))
    script_content = script_template.format(
        uv = uv.path,
        python = python.path,
        dependencies_file = dependencies_file.path,
    )
    ctx.actions.write(executable, script_content, is_executable = True)

    return [DefaultInfo(
        files = depset([executable]),
        executable = executable,
        runfiles = ctx.runfiles([uv, dependencies_file, python]),
    )]

uv_pip_compile = rule(
    implementation = _uv_pip_compile,
    attrs = {
        "constraints_file": attr.label(allow_single_file = True),
        "dependencies_file": attr.label(allow_single_file = True),
        "overrides_file": attr.label(allow_single_file = True),
    },
    toolchains = [
        TARGET_TOOLCHAIN_TYPE,
        UV_TOOLCHAIN_TYPE,
    ],
    executable = True,
)
