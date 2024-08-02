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

_SRCS = {
    Label("@pypi__packaging//:BUILD.bazel"): [
        Label("@pypi__packaging//:packaging/__init__.py"),
        Label("@pypi__packaging//:packaging/_elffile.py"),
        Label("@pypi__packaging//:packaging/_manylinux.py"),
        Label("@pypi__packaging//:packaging/_musllinux.py"),
        Label("@pypi__packaging//:packaging/_parser.py"),
        Label("@pypi__packaging//:packaging/_structures.py"),
        Label("@pypi__packaging//:packaging/_tokenizer.py"),
        Label("@pypi__packaging//:packaging/markers.py"),
        Label("@pypi__packaging//:packaging/metadata.py"),
        Label("@pypi__packaging//:packaging/requirements.py"),
        Label("@pypi__packaging//:packaging/specifiers.py"),
        Label("@pypi__packaging//:packaging/tags.py"),
        Label("@pypi__packaging//:packaging/utils.py"),
        Label("@pypi__packaging//:packaging/version.py"),
    ],
    Label("//:BUILD.bazel"): [
        Label("//python/private/pypi/requirements_parser:resolve_target_platforms.py"),
        Label("//python/private/pypi/whl_installer:platform.py"),
    ],
}

def evaluate_markers(mrctx, *, requirements, python_interpreter, python_interpreter_target, logger = None):
    """Return the list of supported platforms per requirements line.

    Args:
        mrctx: repository_ctx or module_ctx.
        requirements: list[str] of the requirement file lines to evaluate.
        python_interpreter: str, path to the python_interpreter to use to
            evaluate the env markers in the given requirements files. It will
            be only called if the requirements files have env markers. This
            should be something that is in your PATH or an absolute path.
        python_interpreter_target: Label, same as python_interpreter, but in a
            label format.
        logger: repo_utils.logger or None, a simple struct to log diagnostic
            messages. Defaults to None.

    Returns:
        dict of string lists with target platforms
    """
    if not requirements:
        return {}

    _watch_srcs(mrctx)

    in_file = mrctx.path("requirements_with_markers.in.json")
    out_file = mrctx.path("requirements_with_markers.out.json")
    mrctx.file(in_file, json.encode(requirements))

    repo_utils.execute_checked(
        mrctx,
        op = "ResolveRequirementEnvMarkers({})".format(in_file),
        arguments = [
            pypi_repo_utils.resolve_python_interpreter(
                mrctx,
                python_interpreter = python_interpreter,
                python_interpreter_target = python_interpreter_target,
            ),
            "-m",
            "python.private.pypi.requirements_parser.resolve_target_platforms",
            in_file,
            out_file,
        ],
        environment = {
            "PYTHONPATH": pypi_repo_utils.construct_pythonpath(mrctx, entries = _SRCS),
        },
        logger = logger,
    )
    return json.decode(mrctx.read(out_file))

def _watch_srcs(mrctx):
    """watch python srcs that do work here.

    NOTE @aignas 2024-07-13: we could in theory have a label list that
    lists the files that we should include as dependencies to the pip
    repo, however, this way works better because we can select files from
    within the `pypi__packaging` repository and re-execute whenever they
    change. This includes re-executing when the 'packaging' version is
    upgraded.

    Args:
        mrctx: repository_ctx or module_ctx.
    """
    if not hasattr(mrctx, "watch"):
        return

    for _, srcs in _SRCS.items():
        for src in srcs:
            mrctx.watch(mrctx.path(src))
