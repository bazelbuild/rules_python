<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#whl_library"></a>

## whl_library

<pre>
whl_library(<a href="#whl_library-name">name</a>, <a href="#whl_library-extras">extras</a>, <a href="#whl_library-python_interpreter">python_interpreter</a>, <a href="#whl_library-requirements">requirements</a>, <a href="#whl_library-whl">whl</a>)
</pre>

A rule for importing `.whl` dependencies into Bazel.

<b>This rule is currently used to implement `pip_import`. It is not intended to
work standalone, and the interface may change.</b> See `pip_import` for proper
usage.

This rule imports a `.whl` file as a `py_library`:
```python
whl_library(
    name = "foo",
    whl = ":my-whl-file",
    requirements = "name of pip_import rule",
)
```

This rule defines `@foo//:pkg` as a `py_library` target.


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="whl_library-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this repository.
        </p>
      </td>
    </tr>
    <tr id="whl_library-extras">
      <td><code>extras</code></td>
      <td>
        List of strings; optional
        <p>
          A subset of the "extras" available from this <code>.whl</code> for which
<code>requirements</code> has the dependencies.
        </p>
      </td>
    </tr>
    <tr id="whl_library-python_interpreter">
      <td><code>python_interpreter</code></td>
      <td>
        String; optional
        <p>
          The command to run the Python interpreter used when unpacking the wheel.
        </p>
      </td>
    </tr>
    <tr id="whl_library-requirements">
      <td><code>requirements</code></td>
      <td>
        String; optional
        <p>
          The name of the <code>pip_import</code> repository rule from which to load this
<code>.whl</code>'s dependencies.
        </p>
      </td>
    </tr>
    <tr id="whl_library-whl">
      <td><code>whl</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The path to the <code>.whl</code> file. The name is expected to follow [this
convention](https://www.python.org/dev/peps/pep-0427/#file-name-convention)).
        </p>
      </td>
    </tr>
  </tbody>
</table>


