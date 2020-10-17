<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#pip_import"></a>

## pip_import

<pre>
pip_import(<a href="#pip_import-kwargs">kwargs</a>)
</pre>



### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="pip_import-kwargs">
      <td><code>kwargs</code></td>
      <td>
        optional.
      </td>
    </tr>
  </tbody>
</table>


<a name="#pip_install"></a>

## pip_install

<pre>
pip_install(<a href="#pip_install-requirements">requirements</a>, <a href="#pip_install-name">name</a>, <a href="#pip_install-kwargs">kwargs</a>)
</pre>

Imports a `requirements.txt` file and generates a new `requirements.bzl` file.

This is used via the `WORKSPACE` pattern:

```python
pip_install(
    requirements = ":requirements.txt",
)
```

You can then reference imported dependencies from your `BUILD` file with:

```python
load("@pip//:requirements.bzl", "requirement")
py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       requirement("requests"),
       requirement("numpy"),
    ],
)
```


### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="pip_install-requirements">
      <td><code>requirements</code></td>
      <td>
        required.
        <p>
          A 'requirements.txt' pip requirements file.
        </p>
      </td>
    </tr>
    <tr id="pip_install-name">
      <td><code>name</code></td>
      <td>
        optional. default is <code>"pip"</code>
        <p>
          A unique name for the created external repository (default 'pip').
        </p>
      </td>
    </tr>
    <tr id="pip_install-kwargs">
      <td><code>kwargs</code></td>
      <td>
        optional.
        <p>
          Keyword arguments passed directly to the `pip_repository` repository rule.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#pip_repositories"></a>

## pip_repositories

<pre>
pip_repositories()
</pre>





