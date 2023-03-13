<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Core rules for building Python projects.

<a id="current_py_toolchain"></a>

## current_py_toolchain

<pre>
current_py_toolchain(<a href="#current_py_toolchain-name">name</a>)
</pre>


    This rule exists so that the current python toolchain can be used in the `toolchains` attribute of
    other rules, such as genrule. It allows exposing a python toolchain after toolchain resolution has
    happened, to a rule which expects a concrete implementation of a toolchain, rather than a
    toolchain_type which could be resolved to that toolchain.
    

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="current_py_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |


<a id="py_import"></a>

## py_import

<pre>
py_import(<a href="#py_import-name">name</a>, <a href="#py_import-deps">deps</a>, <a href="#py_import-srcs">srcs</a>)
</pre>

This rule allows the use of Python packages as dependencies.

    It imports the given `.egg` file(s), which might be checked in source files,
    fetched externally as with `http_file`, or produced as outputs of other rules.

    It may be used like a `py_library`, in the `deps` of other Python rules.

    This is similar to [java_import](https://docs.bazel.build/versions/master/be/java.html#java_import).
    

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_import-deps"></a>deps |  The list of other libraries to be linked in to the binary target.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |
| <a id="py_import-srcs"></a>srcs |  The list of Python package files provided to Python targets that depend on this target. Note that currently only the .egg format is accepted. For .whl files, try the whl_library rule. We accept contributions to extend py_import to handle .whl.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | <code>[]</code> |


<a id="py_binary"></a>

## py_binary

<pre>
py_binary(<a href="#py_binary-attrs">attrs</a>)
</pre>

See the Bazel core [py_binary](https://docs.bazel.build/versions/master/be/python.html#py_binary) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_binary-attrs"></a>attrs |  Rule attributes   |  none |


<a id="py_library"></a>

## py_library

<pre>
py_library(<a href="#py_library-attrs">attrs</a>)
</pre>

See the Bazel core [py_library](https://docs.bazel.build/versions/master/be/python.html#py_library) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_library-attrs"></a>attrs |  Rule attributes   |  none |


<a id="py_runtime"></a>

## py_runtime

<pre>
py_runtime(<a href="#py_runtime-attrs">attrs</a>)
</pre>

See the Bazel core [py_runtime](https://docs.bazel.build/versions/master/be/python.html#py_runtime) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_runtime-attrs"></a>attrs |  Rule attributes   |  none |


<a id="py_runtime_pair"></a>

## py_runtime_pair

<pre>
py_runtime_pair(<a href="#py_runtime_pair-name">name</a>, <a href="#py_runtime_pair-py2_runtime">py2_runtime</a>, <a href="#py_runtime_pair-py3_runtime">py3_runtime</a>, <a href="#py_runtime_pair-attrs">attrs</a>)
</pre>

A toolchain rule for Python.

This used to wrap up to two Python runtimes, one for Python 2 and one for Python 3.
However, Python 2 is no longer supported, so it now only wraps a single Python 3
runtime.

Usually the wrapped runtimes are declared using the `py_runtime` rule, but any
rule returning a `PyRuntimeInfo` provider may be used.

This rule returns a `platform_common.ToolchainInfo` provider with the following
schema:

```python
platform_common.ToolchainInfo(
    py2_runtime = None,
    py3_runtime = &lt;PyRuntimeInfo or None&gt;,
)
```

Example usage:

```python
# In your BUILD file...

load("@rules_python//python:defs.bzl", "py_runtime_pair")

py_runtime(
    name = "my_py3_runtime",
    interpreter_path = "/system/python3",
    python_version = "PY3",
)

py_runtime_pair(
    name = "my_py_runtime_pair",
    py3_runtime = ":my_py3_runtime",
)

toolchain(
    name = "my_toolchain",
    target_compatible_with = &lt;...&gt;,
    toolchain = ":my_py_runtime_pair",
    toolchain_type = "@rules_python//python:toolchain_type",
)
```

```python
# In your WORKSPACE...

register_toolchains("//my_pkg:my_toolchain")
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_runtime_pair-name"></a>name |  str, the name of the target   |  none |
| <a id="py_runtime_pair-py2_runtime"></a>py2_runtime |  optional Label; must be unset or None; an error is raised otherwise.   |  <code>None</code> |
| <a id="py_runtime_pair-py3_runtime"></a>py3_runtime |  Label; a target with <code>PyRuntimeInfo</code> for Python 3.   |  <code>None</code> |
| <a id="py_runtime_pair-attrs"></a>attrs |  Extra attrs passed onto the native rule   |  none |


<a id="py_test"></a>

## py_test

<pre>
py_test(<a href="#py_test-attrs">attrs</a>)
</pre>

See the Bazel core [py_test](https://docs.bazel.build/versions/master/be/python.html#py_test) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="py_test-attrs"></a>attrs |  Rule attributes   |  none |


<a id="find_requirements"></a>

## find_requirements

<pre>
find_requirements(<a href="#find_requirements-name">name</a>)
</pre>

The aspect definition. Can be invoked on the command line as

    bazel build //pkg:my_py_binary_target         --aspects=@rules_python//python:defs.bzl%find_requirements         --output_groups=pyversioninfo


**ASPECT ATTRIBUTES**


| Name | Type |
| :------------- | :------------- |
| deps| String |


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="find_requirements-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |   |


