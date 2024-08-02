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

"""A simple function that evaluates markers using a python interpreter."""

load("//python/private:repo_utils.bzl", "repo_utils")
load(":pypi_repo_utils.bzl", "pypi_repo_utils")

def evaluate_markers(ctx, *, requirements, python_interpreter, python_interpreter_target, logger):
    """Return the list of supported platforms per requirements line.

    Args:
        ctx: repository_ctx or module_ctx.
        requirements: The requirement file lines to evaluate.
        python_interpreter: str, path to the python_interpreter to use to
            evaluate the env markers in the given requirements files. It will
            be only called if the requirements files have env markers. This
            should be something that is in your PATH or an absolute path.
        python_interpreter_target: Label, same as python_interpreter, but in a
            label format.
        logger: repo_utils.logger or None, a simple struct to log diagnostic messages.

    Returns:
        dict of string lists with target platforms
    """
    if not requirements:
        return {}

    _watch_srcs(ctx)

    in_file = ctx.path("requirements_with_markers.in.json")
    out_file = ctx.path("requirements_with_markers.out.json")
    ctx.file(in_file, json.encode(requirements))

    repo_utils.execute_checked(
        ctx,
        op = "ResolveRequirementEnvMarkers({})".format(in_file),
        arguments = [
            pypi_repo_utils.resolve_python_interpreter(
                ctx,
                python_interpreter = python_interpreter,
                python_interpreter_target = python_interpreter_target,
            ),
            "-m",
            "python.private.pypi.requirements_parser.resolve_target_platforms",
            in_file,
            out_file,
        ],
        environment = {
            "PYTHONPATH": pypi_repo_utils.construct_pythonpath(
                ctx,
                entries = [
                    Label("@pypi__packaging//:BUILD.bazel"),
                    Label("//:MODULE.bazel"),
                ],
            ),
        },
        logger = logger,
    )
    return json.decode(ctx.read(out_file))

def _watch_srcs(ctx):
    """watch python srcs that do work here.

    NOTE @aignas 2024-07-13: we could in theory have a label list that
    lists the files that we should include as dependencies to the pip
    repo, however, this way works better because we can select files from
    within the `pypi__packaging` repository and re-execute whenever they
    change. This includes re-executing when the 'packaging' version is
    upgraded.
    """
    packaging = ctx.path(Label("@pypi__packaging//:BUILD.bazel")).dirname
    if not hasattr(ctx, "watch"):
        return

    srcdir = ctx.path(Label(":BUILD.bazel")).dirname
    for src in [
        srcdir.get_child("whl_installer", "platform.py"),
        srcdir.get_child("requirements_parser", "resolve_target_platforms.py"),
    ] + [
        src
        for src in packaging.readdir(watch = "no")
        if not src.is_dir and src.basename.endswith(".py")
    ]:
        ctx.watch(src)
