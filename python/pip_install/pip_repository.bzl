""

load("//python/pip_install:repositories.bzl", "all_requirements")

def _construct_pypath(rctx):
    """Helper function to construct a PYTHONPATH.

    Contains entries for code in this repo as well as packages downloaded from //python/pip_install:repositories.bzl.
    This allows us to run python code inside repository rule implementations.

    Args:
        rctx: Handle to the repository_context.
    Returns: String of the PYTHONPATH.
    """

    # Get the root directory of these rules
    rules_root = rctx.path(Label("//:BUILD")).dirname
    thirdparty_roots = [
        # Includes all the external dependencies from repositories.bzl
        rctx.path(Label("@" + repo + "//:BUILD.bazel")).dirname
        for repo in all_requirements
    ]
    separator = ":" if not "windows" in rctx.os.name.lower() else ";"
    pypath = separator.join([str(p) for p in [rules_root] + thirdparty_roots])
    return pypath

def _resolve_python_interpreter(rctx):
    """Helper function to find the python interpreter from the common attributes

    Args:
        rctx: Handle to the rule repository context.
    Returns: Python interpreter path.
    """
    python_interpreter = rctx.attr.python_interpreter
    if rctx.attr.python_interpreter_target != None:
        target = rctx.attr.python_interpreter_target
        python_interpreter = rctx.path(target)
    else:
        if "/" not in python_interpreter:
            python_interpreter = rctx.which(python_interpreter)
        if not python_interpreter:
            fail("python interpreter not found")
    return python_interpreter

def _parse_optional_attrs(rctx, args):
    """Helper function to parse common attributes of pip_repository and whl_library repository rules.

    This function also serializes the structured arguments as JSON
    so they can be passed on the command line to subprocesses.

    Args:
        rctx: Handle to the rule repository context.
        args: A list of parsed args for the rule.
    Returns: Augmented args list.
    """

    # Determine whether or not to pass the pip `--isloated` flag to the pip invocation
    use_isolated = rctx.attr.isolated

    # The environment variable will take precedence over the attribute
    isolated_env = rctx.os.environ.get("RULES_PYTHON_PIP_ISOLATED", None)
    if isolated_env != None:
        if isolated_env.lower() in ("0", "false"):
            use_isolated = False
        else:
            use_isolated = True

    if use_isolated:
        args.append("--isolated")

    # Check for None so we use empty default types from our attrs.
    # Some args want to be list, and some want to be dict.
    if rctx.attr.extra_pip_args != None:
        args += [
            "--extra_pip_args",
            struct(arg = rctx.attr.extra_pip_args).to_json(),
        ]

    if rctx.attr.pip_data_exclude != None:
        args += [
            "--pip_data_exclude",
            struct(arg = rctx.attr.pip_data_exclude).to_json(),
        ]

    if rctx.attr.enable_implicit_namespace_pkgs:
        args.append("--enable_implicit_namespace_pkgs")

    if rctx.attr.environment != None:
        args += [
            "--environment",
            struct(arg = rctx.attr.environment).to_json(),
        ]

    return args

_BUILD_FILE_CONTENTS = """\
package(default_visibility = ["//visibility:public"])

# Ensure the `requirements.bzl` source can be accessed by stardoc, since users load() from it
exports_files(["requirements.bzl"])
"""

def _pip_repository_impl(rctx):
    python_interpreter = _resolve_python_interpreter(rctx)

    if rctx.attr.incremental and not rctx.attr.requirements_lock:
        fail("Incremental mode requires a requirements_lock attribute be specified.")

    # We need a BUILD file to load the generated requirements.bzl
    rctx.file("BUILD.bazel", _BUILD_FILE_CONTENTS)

    pypath = _construct_pypath(rctx)

    if rctx.attr.incremental:
        args = [
            python_interpreter,
            "-m",
            "python.pip_install.parse_requirements_to_bzl",
            "--requirements_lock",
            rctx.path(rctx.attr.requirements_lock),
            # pass quiet and timeout args through to child repos.
            "--quiet",
            str(rctx.attr.quiet),
            "--timeout",
            str(rctx.attr.timeout),
        ]

        if rctx.attr.python_interpreter:
            args += ["--python_interpreter", rctx.attr.python_interpreter]
        if rctx.attr.python_interpreter_target:
            args += ["--python_interpreter_target", str(rctx.attr.python_interpreter_target)]
    else:
        args = [
            python_interpreter,
            "-m",
            "python.pip_install.extract_wheels",
            "--requirements",
            rctx.path(rctx.attr.requirements),
        ]

    args += ["--repo", rctx.attr.name]
    args = _parse_optional_attrs(rctx, args)

    result = rctx.execute(
        args,
        # Manually construct the PYTHONPATH since we cannot use the toolchain here
        environment = {"PYTHONPATH": _construct_pypath(rctx)},
        timeout = rctx.attr.timeout,
        quiet = rctx.attr.quiet,
    )

    if result.return_code:
        fail("rules_python failed: %s (%s)" % (result.stdout, result.stderr))

    return

common_env = [
    "RULES_PYTHON_PIP_ISOLATED",
]

common_attrs = {
    "enable_implicit_namespace_pkgs": attr.bool(
        default = False,
        doc = """
If true, disables conversion of native namespace packages into pkg-util style namespace packages. When set all py_binary
and py_test targets must specify either `legacy_create_init=False` or the global Bazel option
`--incompatible_default_to_explicit_init_py` to prevent `__init__.py` being automatically generated in every directory.

This option is required to support some packages which cannot handle the conversion to pkg-util style.
            """,
    ),
    "environment": attr.string_dict(
        doc = """
Environment variables to set in the pip subprocess.
Can be used to set common variables such as `http_proxy`, `https_proxy` and `no_proxy`
Note that pip is run with "--isolated" on the CLI so PIP_<VAR>_<NAME>
style env vars are ignored, but env vars that control requests and urllib3
can be passed.
        """,
        default = {},
    ),
    "extra_pip_args": attr.string_list(
        doc = "Extra arguments to pass on to pip. Must not contain spaces.",
    ),
    "isolated": attr.bool(
        doc = """\
Whether or not to pass the [--isolated](https://pip.pypa.io/en/stable/cli/pip/#cmdoption-isolated) flag to
the underlying pip command. Alternatively, the `RULES_PYTHON_PIP_ISOLATED` enviornment varaible can be used
to control this flag.
""",
        default = True,
    ),
    "pip_data_exclude": attr.string_list(
        doc = "Additional data exclusion parameters to add to the pip packages BUILD file.",
    ),
    "python_interpreter": attr.string(default = "python3"),
    "python_interpreter_target": attr.label(
        allow_single_file = True,
        doc = """
If you are using a custom python interpreter built by another repository rule,
use this attribute to specify its BUILD target. This allows pip_repository to invoke
pip using the same interpreter as your toolchain. If set, takes precedence over
python_interpreter.
""",
    ),
    "quiet": attr.bool(
        default = True,
        doc = "If True, suppress printing stdout and stderr output to the terminal.",
    ),
    # 600 is documented as default here: https://docs.bazel.build/versions/master/skylark/lib/repository_ctx.html#execute
    "timeout": attr.int(
        default = 600,
        doc = "Timeout (in seconds) on the rule's execution duration.",
    ),
}

pip_repository_attrs = {
    "incremental": attr.bool(
        default = False,
        doc = "Create the repository in incremental mode.",
    ),
    "requirements": attr.label(
        allow_single_file = True,
        doc = "A 'requirements.txt' pip requirements file.",
    ),
    "requirements_lock": attr.label(
        allow_single_file = True,
        doc = """
A fully resolved 'requirements.txt' pip requirement file containing the transitive set of your dependencies. If this file is passed instead
of 'requirements' no resolve will take place and pip_repository will create individual repositories for each of your dependencies so that
wheels are fetched/built only for the targets specified by 'build/run/test'.
""",
    ),
}

pip_repository_attrs.update(**common_attrs)

pip_repository = repository_rule(
    attrs = pip_repository_attrs,
    doc = """A rule for importing `requirements.txt` dependencies into Bazel.

This rule imports a `requirements.txt` file and generates a new
`requirements.bzl` file.  This is used via the `WORKSPACE` pattern:

```python
pip_repository(
    name = "foo",
    requirements = ":requirements.txt",
)
```

You can then reference imported dependencies from your `BUILD` file with:

```python
load("@foo//:requirements.bzl", "requirement")
py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       requirement("requests"),
       requirement("numpy"),
    ],
)
```

Or alternatively:
```python
load("@foo//:requirements.bzl", "all_requirements")
py_binary(
    name = "baz",
    ...
    deps = [
       ":foo",
    ] + all_requirements,
)
```
""",
    implementation = _pip_repository_impl,
    environ = common_env,
)

def _impl_whl_library(rctx):
    python_interpreter = _resolve_python_interpreter(rctx)

    # pointer to parent repo so these rules rerun if the definitions in requirements.bzl change.
    _parent_repo_label = Label("@{parent}//:requirements.bzl".format(parent = rctx.attr.repo))
    args = [
        python_interpreter,
        "-m",
        "python.pip_install.parse_requirements_to_bzl.extract_single_wheel",
        "--requirement",
        rctx.attr.requirement,
        "--repo",
        rctx.attr.repo,
    ]
    args = _parse_optional_attrs(rctx, args)

    result = rctx.execute(
        args,
        # Manually construct the PYTHONPATH since we cannot use the toolchain here
        environment = {"PYTHONPATH": _construct_pypath(rctx)},
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.timeout,
    )

    if result.return_code:
        fail("whl_library %s failed: %s (%s)" % (rctx.attr.name, result.stdout, result.stderr))

    return

whl_library_attrs = {
    "repo": attr.string(
        mandatory = True,
        doc = "Pointer to parent repo name. Used to make these rules rerun if the parent repo changes.",
    ),
    "requirement": attr.string(
        mandatory = True,
        doc = "Python requirement string describing the package to make available",
    ),
}

whl_library_attrs.update(**common_attrs)

whl_library = repository_rule(
    attrs = whl_library_attrs,
    doc = """
Download and extracts a single wheel based into a bazel repo based on the requirement string passed in.
Instantiated from pip_repository and inherits config options from there.""",
    implementation = _impl_whl_library,
    environ = common_env,
)
