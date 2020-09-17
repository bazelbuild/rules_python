""

load("//experimental/rules_python_external:repositories.bzl", "all_requirements")

DEFAULT_REPOSITORY_NAME = "pip"

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

    args = [
        python_interpreter,
        "-m",
        "experimental.rules_python_external.extract_wheels",
        "--requirements",
        rctx.path(rctx.attr.requirements),
        "--repo",
        "@%s" % rctx.attr.name,
    ]

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
        fail("rules_python_external failed: %s (%s)" % (result.stdout, result.stderr))

    return

pip_repository = repository_rule(
    attrs = {
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
        "quiet": attr.bool(default = True),
        "requirements": attr.label(allow_single_file = True, mandatory = True),
        # 600 is documented as default here: https://docs.bazel.build/versions/master/skylark/lib/repository_ctx.html#execute
        "timeout": attr.int(default = 600),
    },
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

def pip_install(requirements, name = DEFAULT_REPOSITORY_NAME, **kwargs):
    """Imports a `requirements.txt` file and generates a new `requirements.bzl` file.

    This is used via the `WORKSPACE` pattern:

    ```python
    pip_install(
        requirements = ":requirements.txt",
    )
    ```

    You can then reference imported dependencies from your `BUILD` file with:

    ```python
    load("@pip//:requirements.bzl", "requirement")
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

    Args:
      requirements: A 'requirements.txt' pip requirements file.
      name: A unique name for the created external repository (default 'pip').
      **kwargs: Keyword arguments passed directly to the `pip_repository` repository rule.
    """
    pip_repository(
        name = name,
        requirements = requirements,
        **kwargs
    )
