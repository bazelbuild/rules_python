""

load("//python/pip_install:repositories.bzl", "all_requirements")


def construct_pypath(rctx):
    rctx.file("BUILD", "")

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

def parse_optional_attrs(rctx, args):
    if rctx.attr.extra_pip_args:
        args += [
            "--extra_pip_args",
            struct(args = rctx.attr.extra_pip_args).to_json(),
        ]

    if rctx.attr.pip_data_exclude:
        args += [
            "--pip_data_exclude",
            struct(exclude = rctx.attr.pip_data_exclude).to_json(),
        ]

    if rctx.attr.enable_implicit_namespace_pkgs:
        args.append("--enable_implicit_namespace_pkgs")

    return args


def _pip_repository_impl(rctx):
    python_interpreter = rctx.attr.python_interpreter
    if rctx.attr.python_interpreter_target != None:
        target = rctx.attr.python_interpreter_target
        python_interpreter = rctx.path(target)
    else:
        if "/" not in python_interpreter:
            python_interpreter = rctx.which(python_interpreter)
        if not python_interpreter:
            fail("python interpreter not found")

    if rctx.attr.incremental and not rctx.attr.requirements_lock:
        fail("Incremental mode requires a requirements_lock attribute be specified.")

    pypath = construct_pypath(rctx)

    if rctx.attr.incremental:
        args = [
            python_interpreter,
            "-m",
            "python.pip_install.create_incremental_repo",
            "--requirements_lock",
            rctx.path(rctx.attr.requirements_lock),
            # pass quiet and timeout args through to child repos.
            "--quiet",
            str(rctx.attr.quiet),
            "--timeout",
            str(rctx.attr.timeout),
        ]
    else:
        args = [
            python_interpreter,
            "-m",
            "python.pip_install.extract_wheels",
            "--requirements",
            rctx.path(rctx.attr.requirements),
        ]

    args += ["--repo", rctx.attr.name]
    args = parse_optional_attrs(rctx, args)

    result = rctx.execute(
        args,
        environment = {
            # Manually construct the PYTHONPATH since we cannot use the toolchain here
            "PYTHONPATH": pypath,
        },
        timeout = rctx.attr.timeout,
        quiet = rctx.attr.quiet,
    )

    if result.return_code:
        fail("rules_python failed: %s (%s)" % (result.stdout, result.stderr))

    return


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
    "extra_pip_args": attr.string_list(
        doc = "Extra arguments to pass on to pip. Must not contain spaces.",
    ),
    "pip_data_exclude": attr.string_list(
        doc = "Additional data exclusion parameters to add to the pip packages BUILD file.",
    ),
    "python_interpreter": attr.string(default = "python3"),
    "python_interpreter_target": attr.label(allow_single_file = True, doc = """
If you are using a custom python interpreter built by another repository rule,
use this attribute to specify its BUILD target. This allows pip_repository to invoke
pip using the same interpreter as your toolchain. If set, takes precedence over
python_interpreter.
"""),
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
"""),
    "incremental": attr.bool(
        default = False,
        doc = "Create the repository in incremental form."
    )
}

pip_repository_attrs.update(**common_attrs)

pip_repository = repository_rule(
    attrs = pip_repository_attrs,
    implementation = _pip_repository_impl,
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
)

def _impl_whl_library(rctx):
    # pointer to parent repo so these rules rerun if the definitions in requirements.bzl change.
    _parent_repo_label = Label("@{parent}//:requirements.bzl".format(parent=rctx.attr.repo))
    pypath = construct_pypath(rctx)
    args = [
        rctx.attr.python_interpreter,
        "-m",
        "python.pip_install.create_incremental_repo.extract_single_wheel",
        "--requirement",
        rctx.attr.requirement,
        "--repo",
        rctx.attr.repo,
    ]
    args = parse_optional_attrs(rctx, args)
    result = rctx.execute(
        args,
        environment = {
            # Manually construct the PYTHONPATH since we cannot use the toolchain here
            "PYTHONPATH": pypath,
        },
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.timeout,
    )

    if result.return_code:
        fail("whl_library %s failed: %s (%s)" % (rctx.attr.name, result.stdout, result.stderr))

    return


whl_library_attrs = {
    "requirement": attr.string(mandatory=True, doc = "Python requirement string describing the package to make available"),
    "repo": attr.string(mandatory=True, doc = "Pointer to parent repo name. Used to make these rules rerun if the parent repo changes.")
}

whl_library_attrs.update(**common_attrs)


whl_library = repository_rule(
    attrs = whl_library_attrs,
    implementation = _impl_whl_library,
    doc = """
Download and extracts a single wheel based into a bazel repo based on the requirement string passed in.
Instantiated from pip_repository and inherits config options from there."""
)
