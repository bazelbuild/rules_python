<!-- Generated with Stardoc: http://skydoc.bazel.build -->


Creates an executable (a non-test binary) for console_script entry points.

Generate a `py_binary` target for a particular console_script `entry_point`
from a PyPI package, e.g. for creating an executable `pylint` target use:
```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "pylint",
    pkg = "@pip//pylint",
)
```

Or for more advanced setups you can also specify extra dependencies and the
exact script name you want to call. It is useful for tools like flake8, pylint,
pytest, which have plugin discovery methods and discover dependencies from the
PyPI packages available in the PYTHONPATH.
```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "pylint_with_deps",
    pkg = "@pip//pylint",
    # Because `pylint` has multiple console_scripts available, we have to
    # specify which we want if the name of the target name 'pylint_with_deps'
    # cannot be used to guess the entry_point script.
    script = "pylint",
    deps = [
        # One can add extra dependencies to the entry point.
        # This specifically allows us to add plugins to pylint.
        "@pip//pylint_print",
    ],
)
```

A specific Python version can be forced by using the generated version-aware
wrappers, e.g. to force Python 3.9:
```starlark
load("@python_versions//3.9:defs.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "yamllint",
    pkg = "@pip//yamllint",
)
```

Alternatively, the the `py_console_script_binary.binary_rule` arg can be passed
the version-bound `py_binary` symbol, or any other `py_binary`-compatible rule
of your choosing:
```starlark
load("@python_versions//3.9:defs.bzl", "py_binary")
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "yamllint",
    pkg = "@pip//yamllint:pkg",
    binary_rule = py_binary,
)
```


<a id="py_console_script_binary"></a>

## py_console_script_binary

<pre>
py_console_script_binary(<a href="#py_console_script_binary-name">name</a>, <a href="#py_console_script_binary-pkg">pkg</a>, <a href="#py_console_script_binary-entry_points_txt">entry_points_txt</a>, <a href="#py_console_script_binary-script">script</a>, <a href="#py_console_script_binary-binary_rule">binary_rule</a>, <a href="#py_console_script_binary-kwargs">kwargs</a>)
</pre>

Generate a py_binary for a console_script entry_point.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_console_script_binary-name"></a>name |  str, The name of the resulting target.   |  none |
| <a id="py_console_script_binary-pkg"></a>pkg |  target, the package for which to generate the script.   |  none |
| <a id="py_console_script_binary-entry_points_txt"></a>entry_points_txt |  optional target, the entry_points.txt file to parse for available console_script values. It may be a single file, or a group of files, but must contain a file named <code>entry_points.txt</code>. If not specified, defaults to the <code>dist_info</code> target in the same package as the <code>pkg</code> Label.   |  <code>None</code> |
| <a id="py_console_script_binary-script"></a>script |  str, The console script name that the py_binary is going to be generated for. Defaults to the normalized name attribute.   |  <code>None</code> |
| <a id="py_console_script_binary-binary_rule"></a>binary_rule |  callable, The rule/macro to use to instantiate the target. It's expected to behave like <code>py_binary</code>. Defaults to @rules_python//python:py_binary.bzl#py_binary.   |  <code>&lt;function py_binary&gt;</code> |
| <a id="py_console_script_binary-kwargs"></a>kwargs |  Extra parameters forwarded to binary_rule.   |  none |


