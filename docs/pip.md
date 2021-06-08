<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#pip_import"></a>

## pip_import

<pre>
pip_import(<a href="#pip_import-kwargs">kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| kwargs |  <p align="center"> - </p>   |  none |


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


**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| requirements |  A 'requirements.txt' pip requirements file.   |  none |
| name |  A unique name for the created external repository (default 'pip').   |  <code>"pip"</code> |
| kwargs |  Keyword arguments passed directly to the <code>pip_repository</code> repository rule.   |  none |


<a name="#pip_parse"></a>

## pip_parse

<pre>
pip_parse(<a href="#pip_parse-requirements_lock">requirements_lock</a>, <a href="#pip_parse-name">name</a>, <a href="#pip_parse-kwargs">kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| requirements_lock |  <p align="center"> - </p>   |  none |
| name |  <p align="center"> - </p>   |  <code>"pip_parsed_deps"</code> |
| kwargs |  <p align="center"> - </p>   |  none |


<a name="#pip_repositories"></a>

## pip_repositories

<pre>
pip_repositories()
</pre>



**PARAMETERS**



