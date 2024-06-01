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

"""Functionality shared only by repository rule phase code.

This code should only be loaded and used during the repository phase.
"""

REPO_DEBUG_ENV_VAR = "RULES_PYTHON_REPO_DEBUG"
REPO_VERBOSITY_ENV_VAR = "RULES_PYTHON_REPO_DEBUG_VERBOSITY"

def _is_repo_debug_enabled(rctx):
    """Tells if debbugging output is requested during repo operatiosn.

    Args:
        rctx: repository_ctx object

    Returns:
        True if enabled, False if not.
    """
    return rctx.os.environ.get(REPO_DEBUG_ENV_VAR) == "1"

def _debug_print(rctx, message_cb):
    """Prints a message if repo debugging is enabled.

    Args:
        rctx: repository_ctx
        message_cb: Callable that returns the string to print. Takes
            no arguments.
    """
    if _is_repo_debug_enabled(rctx):
        print(message_cb())  # buildifier: disable=print

def _logger(rctx):
    """Creates a logger instance for printing messages.

    Args:
        rctx: repository_ctx object.

    Returns:
        A struct with attributes logging: trace, debug, info, warn, fail.
    """
    if _is_repo_debug_enabled(rctx):
        verbosity_level = "DEBUG"
    else:
        verbosity_level = "WARN"

    env_var_verbosity = rctx.os.environ.get(REPO_VERBOSITY_ENV_VAR)
    verbosity_level = env_var_verbosity or verbosity_level

    verbosity = {
        "DEBUG": 2,
        "INFO": 1,
        "TRACE": 3,
    }.get(verbosity_level, 0)

    def _log(enabled_on_verbosity, level, message_cb):
        if verbosity < enabled_on_verbosity:
            return

        print("\nrules_python: {}: ".format(level.upper()), message_cb())  # buildifier: disable=print

    return struct(
        trace = lambda message_cb: _log(3, "TRACE", message_cb),
        debug = lambda message_cb: _log(2, "DEBUG", message_cb),
        info = lambda message_cb: _log(1, "INFO", message_cb),
        warn = lambda message_cb: _log(0, "WARNING", message_cb),
    )

def _execute_internal(
        rctx,
        *,
        op,
        fail_on_error = False,
        arguments,
        environment = {},
        **kwargs):
    """Execute a subprocess with debugging instrumention.

    Args:
        rctx: repository_ctx object
        op: string, brief description of the operation this command
            represents. Used to succintly describe it in logging and
            error messages.
        fail_on_error: bool, True if fail() should be called if the command
            fails (non-zero exit code), False if not.
        arguments: list of arguments; see rctx.execute#arguments.
        environment: optional dict of the environment to run the command
            in; see rctx.execute#environment.
        **kwargs: additional kwargs to pass onto rctx.execute

    Returns:
        exec_result object, see repository_ctx.execute return type.
    """
    _debug_print(rctx, lambda: (
        "repo.execute: {op}: start\n" +
        "  command: {cmd}\n" +
        "  working dir: {cwd}\n" +
        "  timeout: {timeout}\n" +
        "  environment:{env_str}\n"
    ).format(
        op = op,
        cmd = _args_to_str(arguments),
        cwd = _cwd_to_str(rctx, kwargs),
        timeout = _timeout_to_str(kwargs),
        env_str = _env_to_str(environment),
    ))

    result = rctx.execute(arguments, environment = environment, **kwargs)

    if fail_on_error and result.return_code != 0:
        fail((
            "repo.execute: {op}: end: failure:\n" +
            "  command: {cmd}\n" +
            "  return code: {return_code}\n" +
            "  working dir: {cwd}\n" +
            "  timeout: {timeout}\n" +
            "  environment:{env_str}\n" +
            "{output}"
        ).format(
            op = op,
            cmd = _args_to_str(arguments),
            return_code = result.return_code,
            cwd = _cwd_to_str(rctx, kwargs),
            timeout = _timeout_to_str(kwargs),
            env_str = _env_to_str(environment),
            output = _outputs_to_str(result),
        ))
    elif _is_repo_debug_enabled(rctx):
        # buildifier: disable=print
        print((
            "repo.execute: {op}: end: {status}\n" +
            "  return code: {return_code}\n" +
            "{output}"
        ).format(
            op = op,
            status = "success" if result.return_code == 0 else "failure",
            return_code = result.return_code,
            output = _outputs_to_str(result),
        ))

    return result

def _execute_unchecked(*args, **kwargs):
    """Execute a subprocess.

    Additional information will be printed if debug output is enabled.

    Args:
        *args: see _execute_internal
        **kwargs: see _execute_internal

    Returns:
        exec_result object, see repository_ctx.execute return type.
    """
    return _execute_internal(fail_on_error = False, *args, **kwargs)

def _execute_checked(*args, **kwargs):
    """Execute a subprocess, failing for a non-zero exit code.

    If the command fails, then fail() is called with detailed information
    about the command and its failure.

    Args:
        *args: see _execute_internal
        **kwargs: see _execute_internal

    Returns:
        exec_result object, see repository_ctx.execute return type.
    """
    return _execute_internal(fail_on_error = True, *args, **kwargs)

def _execute_checked_stdout(*args, **kwargs):
    """Calls execute_checked, but only returns the stdout value."""
    return _execute_checked(*args, **kwargs).stdout

def _which_checked(rctx, binary_name):
    """Tests to see if a binary exists, and otherwise fails with a message.

    Args:
        binary_name: name of the binary to find.
        rctx: repository context.

    Returns:
        rctx.Path for the binary.
    """
    binary = rctx.which(binary_name)
    if binary == None:
        fail((
            "Unable to find the binary '{binary_name}' on PATH.\n" +
            "  PATH = {path}"
        ).format(
            binary_name = binary_name,
            path = rctx.os.environ.get("PATH"),
        ))
    return binary

def _args_to_str(arguments):
    return " ".join([_arg_repr(a) for a in arguments])

def _arg_repr(value):
    if _arg_should_be_quoted(value):
        return repr(value)
    else:
        return str(value)

_SPECIAL_SHELL_CHARS = [" ", "'", '"', "{", "$", "("]

def _arg_should_be_quoted(value):
    # `value` may be non-str, such as ctx.path objects
    value_str = str(value)
    for char in _SPECIAL_SHELL_CHARS:
        if char in value_str:
            return True
    return False

def _cwd_to_str(rctx, kwargs):
    cwd = kwargs.get("working_directory")
    if not cwd:
        cwd = "<default: {}>".format(rctx.path(""))
    return cwd

def _env_to_str(environment):
    if not environment:
        env_str = " <default environment>"
    else:
        env_str = "\n".join(["{}={}".format(k, repr(v)) for k, v in environment.items()])
        env_str = "\n" + env_str
    return env_str

def _timeout_to_str(kwargs):
    return kwargs.get("timeout", "<default timeout>")

def _outputs_to_str(result):
    lines = []
    items = [
        ("stdout", result.stdout),
        ("stderr", result.stderr),
    ]
    for name, content in items:
        if content:
            lines.append("===== {} start =====".format(name))

            # Prevent adding an extra new line, which makes the output look odd.
            if content.endswith("\n"):
                lines.append(content[:-1])
            else:
                lines.append(content)
            lines.append("===== {} end =====".format(name))
        else:
            lines.append("<{} empty>".format(name))
    return "\n".join(lines)

repo_utils = struct(
    execute_checked = _execute_checked,
    execute_unchecked = _execute_unchecked,
    execute_checked_stdout = _execute_checked_stdout,
    is_repo_debug_enabled = _is_repo_debug_enabled,
    debug_print = _debug_print,
    which_checked = _which_checked,
    logger = _logger,
)
