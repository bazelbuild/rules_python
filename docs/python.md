<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#py_runtime_pair"></a>

## py_runtime_pair

<pre>
py_runtime_pair(<a href="#py_runtime_pair-name">name</a>, <a href="#py_runtime_pair-py2_runtime">py2_runtime</a>, <a href="#py_runtime_pair-py3_runtime">py3_runtime</a>)
</pre>

A toolchain rule for Python.

This wraps up to two Python runtimes, one for Python 2 and one for Python 3.
The rule consuming this toolchain will choose which runtime is appropriate.
Either runtime may be omitted, in which case the resulting toolchain will be
unusable for building Python code using that version.

Usually the wrapped runtimes are declared using the `py_runtime` rule, but any
rule returning a `PyRuntimeInfo` provider may be used.

This rule returns a `platform_common.ToolchainInfo` provider with the following
schema:

```python
platform_common.ToolchainInfo(
    py2_runtime = <PyRuntimeInfo or None>,
    py3_runtime = <PyRuntimeInfo or None>,
)
```

Example usage:

```python
# In your BUILD file...

load("@rules_python//python:defs.bzl", "py_runtime_pair")

py_runtime(
    name = "my_py2_runtime",
    interpreter_path = "/system/python2",
    python_version = "PY2",
)

py_runtime(
    name = "my_py3_runtime",
    interpreter_path = "/system/python3",
    python_version = "PY3",
)

py_runtime_pair(
    name = "my_py_runtime_pair",
    py2_runtime = ":my_py2_runtime",
    py3_runtime = ":my_py3_runtime",
)

toolchain(
    name = "my_toolchain",
    target_compatible_with = <...>,
    toolchain = ":my_py_runtime_pair",
    toolchain_type = "@rules_python//python:toolchain_type",
)
```

```python
# In your WORKSPACE...

register_toolchains("//my_pkg:my_toolchain")
```


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_runtime_pair-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="py_runtime_pair-py2_runtime">
      <td><code>py2_runtime</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The runtime to use for Python 2 targets. Must have `python_version` set to
`PY2`.
        </p>
      </td>
    </tr>
    <tr id="py_runtime_pair-py3_runtime">
      <td><code>py3_runtime</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          The runtime to use for Python 3 targets. Must have `python_version` set to
`PY3`.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#py_binary"></a>

## py_binary

<pre>
py_binary(<a href="#py_binary-attrs">attrs</a>)
</pre>

See the Bazel core [py_binary](https://docs.bazel.build/versions/master/be/python.html#py_binary) documentation.

### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_binary-attrs">
      <td><code>attrs</code></td>
      <td>
        optional.
        <p>
          Rule attributes
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#py_library"></a>

## py_library

<pre>
py_library(<a href="#py_library-attrs">attrs</a>)
</pre>

See the Bazel core [py_library](https://docs.bazel.build/versions/master/be/python.html#py_library) documentation.

### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_library-attrs">
      <td><code>attrs</code></td>
      <td>
        optional.
        <p>
          Rule attributes
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#py_runtime"></a>

## py_runtime

<pre>
py_runtime(<a href="#py_runtime-attrs">attrs</a>)
</pre>

See the Bazel core [py_runtime](https://docs.bazel.build/versions/master/be/python.html#py_runtime) documentation.

### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_runtime-attrs">
      <td><code>attrs</code></td>
      <td>
        optional.
        <p>
          Rule attributes
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#py_test"></a>

## py_test

<pre>
py_test(<a href="#py_test-attrs">attrs</a>)
</pre>

See the Bazel core [py_test](https://docs.bazel.build/versions/master/be/python.html#py_test) documentation.

### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="py_test-attrs">
      <td><code>attrs</code></td>
      <td>
        optional.
        <p>
          Rule attributes
        </p>
      </td>
    </tr>
  </tbody>
</table>


