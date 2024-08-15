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

""

load("//python/private:repo_utils.bzl", "repo_utils")

def _get_python_interpreter_attr(ctx, *, python_interpreter = None):
    """A helper function for getting the `python_interpreter` attribute or it's default

    Args:
        ctx (repository_ctx): Handle to the rule repository context.
        python_interpreter (str): The python interpreter override.

    Returns:
        str: The attribute value or it's default
    """
    if python_interpreter:
        return python_interpreter

    os = repo_utils.get_platforms_os_name(ctx)
    if "windows" in os:
        return "python.exe"
    else:
        return "python3"

def _resolve_python_interpreter(ctx, *, python_interpreter = None, python_interpreter_target = None):
    """Helper function to find the python interpreter from the common attributes

    Args:
        ctx: Handle to the rule module_ctx or repository_ctx.
        python_interpreter: The python interpreter to use.
        python_interpreter_target: The python interpreter to use after downloading the label.

    Returns:
        `path` object, for the resolved path to the Python interpreter.
    """
    python_interpreter = _get_python_interpreter_attr(ctx, python_interpreter = python_interpreter)

    if python_interpreter_target != None:
        python_interpreter = ctx.path(python_interpreter_target)

        os = repo_utils.get_platforms_os_name(ctx)

        # On Windows, the symlink doesn't work because Windows attempts to find
        # Python DLLs where the symlink is, not where the symlink points.
        if "windows" in os:
            python_interpreter = python_interpreter.realpath
    elif "/" not in python_interpreter:
        # It's a plain command, e.g. "python3", to look up in the environment.
        found_python_interpreter = ctx.which(python_interpreter)
        if not found_python_interpreter:
            fail("python interpreter `{}` not found in PATH".format(python_interpreter))
        python_interpreter = found_python_interpreter
    else:
        python_interpreter = ctx.path(python_interpreter)
    return python_interpreter

def _construct_pypath(ctx, *, entries):
    """Helper function to construct a PYTHONPATH.

    Contains entries for code in this repo as well as packages downloaded from //python/pip_install:repositories.bzl.
    This allows us to run python code inside repository rule implementations.

    Args:
        ctx: Handle to the module_ctx or repository_ctx.
        entries: The list of entries to add to PYTHONPATH.

    Returns: String of the PYTHONPATH.
    """

    os = repo_utils.get_platforms_os_name(ctx)
    separator = ";" if "windows" in os else ":"
    pypath = separator.join([
        str(ctx.path(entry).dirname)
        # Use a dict as a way to remove duplicates and then sort it.
        for entry in sorted({x: None for x in entries})
    ])
    return pypath

pypi_repo_utils = struct(
    resolve_python_interpreter = _resolve_python_interpreter,
    construct_pythonpath = _construct_pypath,
)
