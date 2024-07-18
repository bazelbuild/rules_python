# Environment Variables

:::{envvar} RULES_PYTHON_REPO_DEBUG

When `1`, repository rules will print debug information about what they're
doing. This is mostly useful for development to debug errors.
:::

:::{envvar} RULES_PYTHON_REPO_DEBUG_VERBOSITY

Determines the verbosity of logging output for repo rules. Valid values:

* `DEBUG`
* `INFO`
* `TRACE`
:::

:::{envvar} RULES_PYTHON_PIP_ISOLATED

Determines if `--isolated` is used with pip.

Valid values:
* `0` and `false` mean to not use isolated mode
* Other non-empty values mean to use isolated mode.
:::

:::{envvar} RULES_PYTHON_BZLMOD_DEBUG

When `1`, bzlmod extensions will print debug information about what they're
doing. This is mostly useful for development to debug errors.
:::

:::{envvar} RULES_PYTHON_ENABLE_PYSTAR

When `1`, the rules_python Starlark implementation of the core rules is used
instead of the Bazel-builtin rules. Note this requires Bazel 7+.
:::

:::{envvar} RULES_PYTHON_BOOTSTRAP_VERBOSE

When `1`, debug information about bootstrapping of a program is printed to
stderr.
:::

:::{envvar} VERBOSE_COVERAGE

When `1`, debug information about coverage behavior is printed to stderr.
:::
