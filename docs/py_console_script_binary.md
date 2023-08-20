<!-- Generated with Stardoc: http://skydoc.bazel.build -->


A macro to generate an console_script py_binary from reading the 'entry_points.txt'.

We can specifically request the console_script to be running with e.g. Python 3.9:
```starlark
load("@python_versions//3.9:defs.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "yamllint",
    pkg = "@pip//yamllint",
    # yamllint does not have any other scripts except 'yamllint' so the
    # user does not have to specify which console script we should chose from
    # the package.
)
```

Or just use the default version:
```starlark
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")

py_console_script_binary(
    name = "pylint",
    pkg = "@pip//pylint",
    # Because `pylint` has multiple console_scripts available, we have to
    # specify which we want
    script = "pylint",
    deps = [
        # One can add extra dependencies to the entry point.
        # This specifically allows us to add plugins to pylint.
        "@pip//pylint_print",
    ],
)
```


<a id="py_console_script_binary"></a>

## py_console_script_binary

<pre>
py_console_script_binary(<a href="#py_console_script_binary-name">name</a>, <a href="#py_console_script_binary-pkg">pkg</a>, <a href="#py_console_script_binary-script">script</a>, <a href="#py_console_script_binary-binary_rule">binary_rule</a>, <a href="#py_console_script_binary-kwargs">kwargs</a>)
</pre>

Generate a py_binary for a console_script entry_point.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_console_script_binary-name"></a>name |  The name of the resultant binary_rule target.   |  none |
| <a id="py_console_script_binary-pkg"></a>pkg |  The package for which to generate the script.   |  none |
| <a id="py_console_script_binary-script"></a>script |  The console script name that the py_binary is going to be generated for. Mandatory only if there is more than 1 console_script in the package.   |  <code>None</code> |
| <a id="py_console_script_binary-binary_rule"></a>binary_rule |  The binary rule to call to create the py_binary. Defaults to @rules_python//python:py_binary.bzl#py_binary.   |  <code>&lt;function py_binary&gt;</code> |
| <a id="py_console_script_binary-kwargs"></a>kwargs |  Extra parameters forwarded to binary_rule.   |  none |


