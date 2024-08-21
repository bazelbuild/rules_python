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

"""A simple macro to pin the requirements.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//python:py_binary.bzl", "py_binary")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility

_REQUIREMENTS_TARGET_COMPATIBLE_WITH = select({
    "@platforms//os:linux": [],
    "@platforms//os:macos": [],
    "//conditions:default": ["@platforms//:incompatible"],
}) if BZLMOD_ENABLED else ["@platforms//:incompatible"]

def pin(*, name, srcs, out, upgrade = False, universal = True, python_version = None):
    """Pin the requirements based on the src files.

    Args:
        name: The name of the target to run for updating the requirements.
        srcs: The srcs to use as inputs.
        out: The output file.
        upgrade: Tell `uv` to always upgrade the dependencies instead of
            keeping them as they are.
        universal: Tell `uv` to generate a universal lock file.
        python_version: Tell `rules_python` to use a particular version.
            Defaults to the default py toolchain.

    Differences with the current pip-compile rule:
    - This is implemented in shell and uv.
    - This does not error out if the output file does not exist yet.
    - Supports transitions out of the box.
    """
    pkg = native.package_name()
    _out = "_" + out

    args = [
        "--custom-compile-command='bazel run //{}:{}'".format(pkg, name),
        "--generate-hashes",
        "--emit-index-url",
        "--no-strip-extras",
        "--python=$(PYTHON3)",
    ] + [
        "$(location {})".format(src)
        for src in srcs
    ] + [
        "--output-file=$(location {})".format(_out),
    ]
    if upgrade:
        args.append("--upgrade")
    if universal:
        args.append("--universal")
    cmd = "$(UV_BIN) pip compile " + " ".join(args)

    # Check if the output file already exists, if yes, first copy it to the
    # output file location in order to make `uv` not change the requirements if
    # we are just running the command.
    if native.glob([out]):
        cmd = "cp -v $(location {}) $@; {}".format(out, cmd)
        srcs.append(out)

    native.genrule(
        name = name + ".uv.out",
        srcs = srcs,
        outs = [_out],
        cmd_bash = cmd,
        tags = [
            "local",
            "manual",
            "no-cache",
        ],
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
        toolchains = [
            Label("//python/uv:current_toolchain"),
            Label("//python:current_py_toolchain"),
        ],
    )
    if python_version:
        transitioned_name = "{}.uv.out.{}".format(name, python_version)
        _versioned(
            name = transitioned_name,
            src = _out,
            python_version = python_version,
            tags = ["manual"],
        )
        _out = transitioned_name

    # Write a script that can be used for updating the in-tree version of the
    # requirements file
    write_file(
        name = name + ".gen",
        out = name + ".gen.py",
        content = [
            "from os import environ",
            "from pathlib import Path",
            "from sys import stderr",
            "",
            'src = Path(environ["REQUIREMENTS_FILE"])',
            'dst = Path(environ["BUILD_WORKSPACE_DIRECTORY"]) / "{}" / "{}"'.format(pkg, out),
            'print(f"Writing requirements contents\\n  from {src.absolute()}\\n  to {dst.absolute()}", file=stderr)',
            "dst.write_text(src.read_text())",
            'print("Success!", file=stderr)',
        ],
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
    )

    py_binary(
        name = name,
        srcs = [name + ".gen.py"],
        main = name + ".gen.py",
        data = [_out],
        env = {
            "REQUIREMENTS_FILE": "$(location {})".format(_out),
        },
        tags = ["manual"],
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
    )

def _transition_python_version_impl(_, attr):
    return {"//python/config_settings:python_version": str(attr.python_version)}

_transition_python_version = transition(
    implementation = _transition_python_version_impl,
    inputs = [],
    outputs = ["//python/config_settings:python_version"],
)

def _impl(ctx):
    target = ctx.attr.src

    default_info = target[0][DefaultInfo]
    files = default_info.files
    original_executable = default_info.files_to_run.executable
    runfiles = default_info.default_runfiles

    new_executable = ctx.actions.declare_file(ctx.attr.name)

    ctx.actions.symlink(
        output = new_executable,
        target_file = original_executable,
        is_executable = True,
    )

    files = depset(direct = [new_executable], transitive = [files])
    runfiles = runfiles.merge(ctx.runfiles([new_executable]))

    return [
        DefaultInfo(
            files = files,
            runfiles = runfiles,
            executable = new_executable,
        ),
    ]

_versioned = rule(
    implementation = _impl,
    attrs = {
        "python_version": attr.string(
            mandatory = True,
        ),
        "src": attr.label(
            allow_single_file = True,
            executable = False,
            mandatory = True,
            cfg = _transition_python_version,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)
