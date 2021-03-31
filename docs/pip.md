<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#pip_import"></a>

## pip_import

<pre>
pip_import(<a href="#pip_import-name">name</a>, <a href="#pip_import-extra_pip_args">extra_pip_args</a>, <a href="#pip_import-python_interpreter">python_interpreter</a>, <a href="#pip_import-python_interpreter_target">python_interpreter_target</a>, <a href="#pip_import-requirements">requirements</a>, <a href="#pip_import-timeout">timeout</a>)
</pre>

A rule for importing `requirements.txt` dependencies into Bazel.

This rule imports a `requirements.txt` file and generates a new
`requirements.bzl` file.  This is used via the `WORKSPACE` pattern:

```python
pip_import(
    name = "foo",
    requirements = ":requirements.txt",
)
load("@foo//:requirements.bzl", "pip_install")
pip_install()
```

You can then reference imported dependencies from your `BUILD` file with:

```python
load("@foo//:requirements.bzl", "requirement")
py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       requirement("futures"),
       requirement("mock"),
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


### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="pip_import-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this repository.
        </p>
      </td>
    </tr>
    <tr id="pip_import-extra_pip_args">
      <td><code>extra_pip_args</code></td>
      <td>
        List of strings; optional
        <p>
          Extra arguments to pass on to pip. Must not contain spaces.
        </p>
      </td>
    </tr>
    <tr id="pip_import-python_interpreter">
      <td><code>python_interpreter</code></td>
      <td>
        String; optional
        <p>
          The command to run the Python interpreter used to invoke pip and unpack the
wheels.
        </p>
      </td>
    </tr>
    <tr id="pip_import-python_interpreter_target">
      <td><code>python_interpreter_target</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          If you are using a custom python interpreter built by another repository rule,
use this attribute to specify its BUILD target. This allows pip_import to invoke
pip using the same interpreter as your toolchain. If set, takes precedence over
python_interpreter.
        </p>
      </td>
    </tr>
    <tr id="pip_import-requirements">
      <td><code>requirements</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The label of the requirements.txt file.
        </p>
      </td>
    </tr>
    <tr id="pip_import-timeout">
      <td><code>timeout</code></td>
      <td>
        Integer; optional
        <p>
          Timeout (in seconds) for repository fetch.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#pip3_import"></a>

## pip3_import

<pre>
pip3_import(<a href="#pip3_import-kwargs">kwargs</a>)
</pre>

A wrapper around pip_import that uses the `python3` system command.

Use this for requirements of PY3 programs.

### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="pip3_import-kwargs">
      <td><code>kwargs</code></td>
      <td>
        optional.
      </td>
    </tr>
  </tbody>
</table>


<a name="#pip_repositories"></a>

## pip_repositories

<pre>
pip_repositories()
</pre>

Pull in dependencies needed to use the packaging rules.



