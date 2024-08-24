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

"""A simple macro to lock the requirements.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//python:py_binary.bzl", "py_binary")
load("//python/config_settings:transition.bzl", transition_py_binary = "py_binary")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility

visibility(["//..."])

_REQUIREMENTS_TARGET_COMPATIBLE_WITH = [] if BZLMOD_ENABLED else ["@platforms//:incompatible"]

def lock(*, name, srcs, out, upgrade = False, universal = True, python_version = None):
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
    update_target = name + ".update"

    args = [
        "--custom-compile-command='bazel run //{}:{}'".format(pkg, update_target),
        "--generate-hashes",
        "--emit-index-url",
        "--no-strip-extras",
        "--python=$(PYTHON3)",
    ] + [
        "$(location {})".format(src)
        for src in srcs
    ]
    if upgrade:
        args.append("--upgrade")
    if universal:
        args.append("--universal")
    args.append("--output-file=$@")
    cmd = "$(UV_BIN) pip compile " + " ".join(args)

    # Check if the output file already exists, if yes, first copy it to the
    # output file location in order to make `uv` not change the requirements if
    # we are just running the command.
    if native.glob([out]):
        cmd = "cp -v $(location {}) $@; {}".format(out, cmd)
        srcs.append(out)

    native.genrule(
        name = name,
        srcs = srcs,
        outs = [out + ".new"],
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
        py_binary_rule = lambda *args, **kwargs: transition_py_binary(python_version = python_version, *args, **kwargs)
    else:
        py_binary_rule = py_binary

    # Write a script that can be used for updating the in-tree version of the
    # requirements file
    write_file(
        name = name + ".update_gen",
        out = update_target + ".py",
        content = [
            "from os import environ",
            "from pathlib import Path",
            "from sys import stderr",
            "",
            'src = Path(environ["REQUIREMENTS_FILE"])',
            'assert src.exists(), f"the {src} file does not exist"',
            'dst = Path(environ["BUILD_WORKSPACE_DIRECTORY"]) / "{}" / "{}"'.format(pkg, out),
            'print(f"Writing requirements contents\\n  from {src.absolute()}\\n  to {dst.absolute()}", file=stderr)',
            "dst.write_text(src.read_text())",
            'print("Success!", file=stderr)',
        ],
    )

    py_binary_rule(
        name = update_target,
        srcs = [update_target + ".py"],
        main = update_target + ".py",
        data = [name],
        env = {
            "REQUIREMENTS_FILE": "$(rootpath {})".format(name),
        },
        tags = ["manual"],
    )