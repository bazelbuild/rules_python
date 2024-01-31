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

""

load("//python:versions.bzl", "WINDOWS_NAME")
load("//python/pip_install:repositories.bzl", "all_requirements")
load("//python/private:toolchains_repo.bzl", "get_host_os_arch")

def _construct_pypath(rctx):
    """Helper function to construct a PYTHONPATH.

    Contains entries for code in this repo as well as packages downloaded from //python/pip_install:repositories.bzl.
    This allows us to run python code inside repository rule implementations.

    Args:
        rctx: Handle to the repository_context.

    Returns: String of the PYTHONPATH.
    """

    separator = ":" if not "windows" in rctx.os.name.lower() else ";"
    pypath = separator.join([
        str(rctx.path(entry).dirname)
        for entry in rctx.attr._python_path_entries
    ])
    return pypath

def _get_python_interpreter_attr(rctx):
    """A helper function for getting the `python_interpreter` attribute or it's default

    Args:
        rctx (repository_ctx): Handle to the rule repository context.

    Returns:
        str: The attribute value or it's default
    """
    if rctx.attr.python_interpreter:
        return rctx.attr.python_interpreter

    if "win" in rctx.os.name:
        return "python.exe"
    else:
        return "python3"

def _resolve_python_interpreter(rctx):
    """Helper function to find the python interpreter from the common attributes

    Args:
        rctx: Handle to the rule repository context.

    Returns:
        `path` object, for the resolved path to the Python interpreter.
    """
    python_interpreter = _get_python_interpreter_attr(rctx)

    if rctx.attr.python_interpreter_target != None:
        python_interpreter = rctx.path(rctx.attr.python_interpreter_target)

        (os, _) = get_host_os_arch(rctx)

        # On Windows, the symlink doesn't work because Windows attempts to find
        # Python DLLs where the symlink is, not where the symlink points.
        if os == WINDOWS_NAME:
            python_interpreter = python_interpreter.realpath
    elif "/" not in python_interpreter:
        # It's a plain command, e.g. "python3", to look up in the environment.
        found_python_interpreter = rctx.which(python_interpreter)
        if not found_python_interpreter:
            fail("python interpreter `{}` not found in PATH".format(python_interpreter))
        python_interpreter = found_python_interpreter
    else:
        python_interpreter = rctx.path(python_interpreter)
    return python_interpreter

def _impl(rctx):
    python_interpreter = _resolve_python_interpreter(rctx)
    args = [
        python_interpreter,
        "-c",
        """\
# Import from stdlib
import sys

# Add a third party package to ensure PYTHONPATH setting works
import packaging

print(packaging.__version__)
sys.exit(1)
""",
    ]

    # Manually construct the PYTHONPATH since we cannot use the toolchain here
    environment = {
        "PYTHONPATH": _construct_pypath(rctx),
    }

    result = rctx.execute(
        args,
        environment = environment,
        quiet = False,
        timeout = 60,
    )
    if result.return_code:
        fail((
            "repro_rule '{name}' failed:\n" +
            "  command: {cmd}\n" +
            "  environment:\n{env}\n" +
            "  return code: {return_code}\n" +
            "===== stdout start ====\n{stdout}\n===== stdout end===\n" +
            "===== stderr start ====\n{stderr}\n===== stderr end===\n"
        ).format(
            name = rctx.attr.name,
            cmd = " ".join([str(a) for a in args]),
            env = "\n".join(["{}={}".format(k, v) for k, v in environment.items()]),
            return_code = result.return_code,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    return

repro_rule = repository_rule(
    attrs = {
        "python_interpreter": attr.string(
            doc = """\
    The python interpreter to use. This can either be an absolute path or the name
    of a binary found on the host's `PATH` environment variable. If no value is set
    `python3` is defaulted for Unix systems and `python.exe` for Windows.
    """,
            # NOTE: This attribute should not have a default. See `_get_python_interpreter_attr`
            # default = "python3"
        ),
        "python_interpreter_target": attr.label(
            allow_single_file = True,
            doc = """
    If you are using a custom python interpreter built by another repository rule,
    use this attribute to specify its BUILD target. This allows pip_repository to invoke
    pip using the same interpreter as your toolchain. If set, takes precedence over
    python_interpreter. An example value: "@python3_x86_64-unknown-linux-gnu//:python".
    """,
        ),
        "_python_path_entries": attr.label_list(
            # Get the root directory of these rules and keep them as a default attribute
            # in order to avoid unnecessary repository fetching restarts.
            #
            # This is very similar to what was done in https://github.com/bazelbuild/rules_go/pull/3478
            default = [
                Label("//:BUILD.bazel"),
            ] + [
                # Includes all the external dependencies from repositories.bzl
                Label("@" + repo + "//:BUILD.bazel")
                for repo in all_requirements
            ],
        ),
    },
    implementation = _impl,
)
