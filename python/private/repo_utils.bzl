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
    return _getenv(rctx, REPO_DEBUG_ENV_VAR) == "1"

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
        rctx: repository_ctx object. If the attribute `_rule_name` is
            present, it will be included in log messages.

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

    def _log(enabled_on_verbosity, level, message_cb_or_str):
        if verbosity < enabled_on_verbosity:
            return
        rule_name = getattr(rctx.attr, "_rule_name", "?")
        if type(message_cb_or_str) == "string":
            message = message_cb_or_str
        else:
            message = message_cb_or_str()

        print("\nrules_python:{}(@@{}) {}:".format(
            rule_name,
            rctx.name,
            level.upper(),
        ), message)  # buildifier: disable=print

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
    """Execute a subprocess with debugging instrumentation.

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

    rctx.report_progress("Running {}".format(op))
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

    result_kwargs = {k: getattr(result, k) for k in dir(result)}
    return struct(
        describe_failure = lambda: _execute_describe_failure(
            op = op,
            arguments = arguments,
            result = result,
            rctx = rctx,
            kwargs = kwargs,
            environment = environment,
        ),
        **result_kwargs
    )

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

def _execute_describe_failure(*, op, arguments, result, rctx, kwargs, environment):
    return (
        "repo.execute: {op}: failure:\n" +
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
    )

def _which_checked(rctx, binary_name):
    """Tests to see if a binary exists, and otherwise fails with a message.

    Args:
        binary_name: name of the binary to find.
        rctx: repository context.

    Returns:
        rctx.Path for the binary.
    """
    result = _which_unchecked(rctx, binary_name)
    if result.binary == None:
        fail(result.describe_failure())
    return result.binary

def _which_unchecked(rctx, binary_name):
    """Tests to see if a binary exists.

    This is also watch the `PATH` environment variable.

    Args:
        binary_name: name of the binary to find.
        rctx: repository context.

    Returns:
        `struct` with attributes:
        * `binary`: `repository_ctx.Path`
        * `describe_failure`: `Callable | None`; takes no args. If the
          binary couldn't be found, provides a detailed error description.
    """
    path = _getenv(rctx, "PATH", "")
    binary = rctx.which(binary_name)
    if binary:
        _watch(rctx, binary)
        describe_failure = None
    else:
        describe_failure = lambda: _which_describe_failure(binary_name, path)

    return struct(
        binary = binary,
        describe_failure = describe_failure,
    )

def _which_describe_failure(binary_name, path):
    return (
        "Unable to find the binary '{binary_name}' on PATH.\n" +
        "  PATH = {path}"
    ).format(
        binary_name = binary_name,
        path = path,
    )

def _getenv(rctx, name, default = None):
    # Bazel 7+ API
    if hasattr(rctx, "getenv"):
        return rctx.getenv(name, default)
    else:
        return rctx.os.environ.get("PATH", default)

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

# This includes the vendored _translate_cpu and _translate_os from
# @platforms//host:extension.bzl at version 0.0.9 so that we don't
# force the users to depend on it.

def _get_platforms_os_name(rctx):
    """Return the name in @platforms//os for the host os.

    Args:
        rctx: repository_ctx

    Returns:
        `str`. The target name.
    """
    os = rctx.os.name.lower()

    if os.startswith("mac os"):
        return "osx"
    if os.startswith("freebsd"):
        return "freebsd"
    if os.startswith("openbsd"):
        return "openbsd"
    if os.startswith("linux"):
        return "linux"
    if os.startswith("windows"):
        return "windows"
    return os

def _get_platforms_cpu_name(rctx):
    """Return the name in @platforms//cpu for the host arch.

    Args:
        rctx: repository_ctx

    Returns:
        `str`. The target name.
    """
    arch = rctx.os.arch.lower()
    if arch in ["i386", "i486", "i586", "i686", "i786", "x86"]:
        return "x86_32"
    if arch in ["amd64", "x86_64", "x64"]:
        return "x86_64"
    if arch in ["ppc", "ppc64", "ppc64le"]:
        return "ppc"
    if arch in ["arm", "armv7l"]:
        return "arm"
    if arch in ["aarch64"]:
        return "aarch64"
    if arch in ["s390x", "s390"]:
        return "s390x"
    if arch in ["mips64el", "mips64"]:
        return "mips64"
    if arch in ["riscv64"]:
        return "riscv64"
    return arch

# TODO: Remove after Bazel 6 support dropped
def _watch(rctx, *args, **kwargs):
    """Calls rctx.watch, if available."""
    if hasattr(rctx, "watch"):
        rctx.watch(*args, **kwargs)

# TODO: Remove after Bazel 6 support dropped
def _watch_tree(rctx, *args, **kwargs):
    """Calls rctx.watch_tree, if available."""
    if hasattr(rctx, "watch_tree"):
        rctx.watch_tree(*args, **kwargs)

repo_utils = struct(
    # keep sorted
    debug_print = _debug_print,
    execute_checked = _execute_checked,
    execute_checked_stdout = _execute_checked_stdout,
    execute_unchecked = _execute_unchecked,
    get_platforms_cpu_name = _get_platforms_cpu_name,
    get_platforms_os_name = _get_platforms_os_name,
    getenv = _getenv,
    is_repo_debug_enabled = _is_repo_debug_enabled,
    logger = _logger,
    watch = _watch,
    watch_tree = _watch_tree,
    which_checked = _which_checked,
    which_unchecked = _which_unchecked,
)
