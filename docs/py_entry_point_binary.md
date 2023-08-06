<!-- Generated with Stardoc: http://skydoc.bazel.build -->


A macro to generate an entry_point from reading the 'console_scripts'.

We can specifically request the entry_point to be running with e.g. Python 3.9:
```starlark
load("@python_versions//3.9:defs.bzl", "entry_point")

entry_point(
    name = "yamllint",
    pkg = "@pip//yamllint",
    # yamllint does not have any other scripts except 'yamllint' so the
    # user does not have to specify which console script we should chose from
    # the package.
)
```

Or just use the default version:
```starlark
load("@rules_python//python:py_entry_point_binary.bzl", "entry_point")

entry_point(
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


<a id="py_entry_point_binary"></a>

## py_entry_point_binary

<pre>
py_entry_point_binary(<a href="#py_entry_point_binary-name">name</a>, <a href="#py_entry_point_binary-pkg">pkg</a>, <a href="#py_entry_point_binary-script">script</a>, <a href="#py_entry_point_binary-deps">deps</a>, <a href="#py_entry_point_binary-binary_rule">binary_rule</a>, <a href="#py_entry_point_binary-kwargs">kwargs</a>)
</pre>

Generate an entry_point for a given package

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_entry_point_binary-name"></a>name |  The name of the resultant binary_rule target.   |  none |
| <a id="py_entry_point_binary-pkg"></a>pkg |  The package for which to generate the script.   |  none |
| <a id="py_entry_point_binary-script"></a>script |  The console script that the entry_point is going to be generated. Mandatory if there are more than 1 console_script in the package.   |  <code>None</code> |
| <a id="py_entry_point_binary-deps"></a>deps |  The extra dependencies to add to the binary_rule rule.   |  <code>None</code> |
| <a id="py_entry_point_binary-binary_rule"></a>binary_rule |  The binary rule to call to create the entry_point binary. Defaults to @rules_python//python:py_binary.bzl#py_binary.   |  <code>&lt;function py_binary&gt;</code> |
| <a id="py_entry_point_binary-kwargs"></a>kwargs |  Extra parameters forwarded to binary_rule.   |  none |


