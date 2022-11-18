<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#current_py_toolchain"></a>

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
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |


<a name="#py_import"></a>

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
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  The list of other libraries to be linked in to the binary target.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| srcs |  The list of Python package files provided to Python targets that depend on this target. Note that currently only the .egg format is accepted. For .whl files, try the whl_library rule. We accept contributions to extend py_import to handle .whl.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a name="#py_binary"></a>

## py_binary

<pre>
py_binary(<a href="#py_binary-attrs">attrs</a>)
</pre>

See the Bazel core [py_binary](https://docs.bazel.build/versions/master/be/python.html#py_binary) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| attrs |  Rule attributes   |  none |


<a name="#py_library"></a>

## py_library

<pre>
py_library(<a href="#py_library-attrs">attrs</a>)
</pre>

See the Bazel core [py_library](https://docs.bazel.build/versions/master/be/python.html#py_library) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| attrs |  Rule attributes   |  none |


<a name="#py_runtime"></a>

## py_runtime

<pre>
py_runtime(<a href="#py_runtime-attrs">attrs</a>)
</pre>

See the Bazel core [py_runtime](https://docs.bazel.build/versions/master/be/python.html#py_runtime) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| attrs |  Rule attributes   |  none |


<a name="#py_runtime_pair"></a>

## py_runtime_pair

<pre>
py_runtime_pair(<a href="#py_runtime_pair-attrs">attrs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| attrs |  <p align="center"> - </p>   |  none |


<a name="#py_test"></a>

## py_test

<pre>
py_test(<a href="#py_test-attrs">attrs</a>)
</pre>

See the Bazel core [py_test](https://docs.bazel.build/versions/master/be/python.html#py_test) documentation.

**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| attrs |  Rule attributes   |  none |


<a name="#find_requirements"></a>

## find_requirements

<pre>
find_requirements(<a href="#find_requirements-name">name</a>)
</pre>

The aspect definition. Can be invoked on the command line as

    bazel build //pkg:my_py_binary_target         --aspects=@rules_python//python:defs.bzl%find_requirements         --output_groups=pyversioninfo


**ASPECT ATTRIBUTES**


| Name | Type |
| :-------------: | :-------------: |
| deps| String |


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |   |


