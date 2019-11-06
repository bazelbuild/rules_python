<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#whl_library"></a>

## whl_library

<pre>
whl_library(<a href="#whl_library-name">name</a>, <a href="#whl_library-extras">extras</a>, <a href="#whl_library-requirements">requirements</a>, <a href="#whl_library-whl">whl</a>)
</pre>

A rule for importing <code>.whl</code> dependencies into Bazel.

<b>This rule is currently used to implement <code>pip_import</code>,
it is not intended to work standalone, and the interface may change.</b>
See <code>pip_import</code> for proper usage.

This rule imports a <code>.whl</code> file as a <code>py_library</code>:
<pre><code>whl_library(
    name = "foo",
    whl = ":my-whl-file",
    requirements = "name of pip_import rule",
)
</code></pre>

This rule defines a <code>@foo//:pkg</code> <code>py_library</code> target.

Args:
  whl: The path to the .whl file (the name is expected to follow [this
    convention](https://www.python.org/dev/peps/pep-0427/#file-name-convention))

  requirements: The name of the pip_import repository rule from which to
    load this .whl's dependencies.

  extras: A subset of the "extras" available from this <code>.whl</code> for which
    <code>requirements</code> has the dependencies.


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
      </td>
    </tr>
    <tr id="whl_library-requirements">
      <td><code>requirements</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="whl_library-whl">
      <td><code>whl</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
      </td>
    </tr>
  </tbody>
</table>


