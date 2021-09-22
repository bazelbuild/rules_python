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


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| extras |  A subset of the "extras" available from this <code>.whl</code> for which <code>requirements</code> has the dependencies.   | List of strings | optional | [] |
| python_interpreter |  The command to run the Python interpreter used when unpacking the wheel.   | String | optional | "python" |
| requirements |  The name of the <code>pip_import</code> repository rule from which to load this <code>.whl</code>'s dependencies.   | String | optional | "" |
| whl |  The path to the <code>.whl</code> file. The name is expected to follow [this convention](https://www.python.org/dev/peps/pep-0427/#file-name-convention)).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


