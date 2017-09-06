# Bazel Python Rules

[![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_python)](http://ci.bazel.io/job/rules_python)

## Rules

* [pip_import](#pip_import)
* [py_library](#py_library)
* [py_binary](#py_binary)
* [py_test](#py_test)

## Overview

This repository provides Python rules for Bazel.  Currently, support for
rules that are available from Bazel core are simple aliases to that bundled
functionality.  On top of that, this repository provides support for installing
dependencies typically managed via `pip`.

## Setup

Add the following to your `WORKSPACE` file to add the external repositories:

```python
git_repository(
    name = "io_bazel_rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    commit = "{HEAD}",
)

# Only needed for PIP support:
load("//python:pip.bzl", "pip_repositories")

pip_repositories()
```

Then in your `BUILD` files load the python rules with:

``` python
load(
  "@io_bazel_rules_python//python:python.bzl",
  "py_binary", "py_library", "py_test",
)

py_binary(
  name = "main",
  ...
)
```

## Importing `pip` dependencies

These rules are designed to have developers continue using `requirements.txt`
to express their dependencies in a Python idiomatic manner.  These dependencies
are imported into the Bazel dependency graph via a two-phased process in
`WORKSPACE`:

```python
load("@io_bazel_rules_python//python:pip.bzl", "pip_import")

# This rule translates the specified requirements.txt into
# @my_deps//:requirements.bzl, which itself exposes a pip_install method.
pip_import(
   name = "my_deps",
   requirements = "//path/to:requirements.txt",
)

# Load the pip_install symbol for my_deps, and create the dependencies'
# repositories.
load("@my_deps//:requirements.bzl", "pip_install")
pip_install()
```

## Consuming `pip` dependencies

Once a set of dependencies has been imported via `pip_import` and `pip_install`
we can start consuming them in our `py_{binary,library,test}` rules.  In support
of this, the generated `requirements.bzl` also contains a `packages` method,
which can be used directly in `deps=[]` to reference an imported `py_library`.

```python
load("@my_deps//:requirements.txt", "packages")

py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        ":myotherlib",
	# This takes the name as specified in requirements.txt
	packages("importeddep"),
    ]
)
```


<a name="py_library"></a>
## py_library

See Bazel core [documentation](https://docs.bazel.build/versions/master/be/python.html#py_library).

<a name="py_binary"></a>
## py_binary

See Bazel core [documentation](https://docs.bazel.build/versions/master/be/python.html#py_binary).

<a name="py_test"></a>
## py_test

See Bazel core [documentation](https://docs.bazel.build/versions/master/be/python.html#py_test).

<a name="pip_import"></a>
## pip_import

```python
pip_import(name, requirements)
```

A repository rule that imports a `requirements.txt` file and generates
`requirements.bzl`.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code>Name, required</code></p>
        <p>Unique name for this repository rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>requirements</code></td>
      <td>
        <p><code>A requirements.txt file; required</code></p>
        <p>This takes the path to a the <code>requirements.txt</code> file that
	   expresses the Python library dependencies in an idiomatic manner.</p>
      </td>
    </tr>
  </tbody>
</table>
