# Bazel Python Rules

[![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_python)](http://ci.bazel.io/job/rules_python)

## Rules

* [pip_import](docs/python/pip.md#pip_import)
* [py_library](docs/python/python.md#py_library)
* [py_binary](docs/python/python.md#py_binary)
* [py_test](docs/python/python.md#py_test)

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
of this, the generated `requirements.bzl` also contains a `package` method,
which can be used directly in `deps=[]` to reference an imported `py_library`.

```python
load("@my_deps//:requirements.bzl", "package")

py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        ":myotherlib",
	# This takes the name as specified in requirements.txt
	package("importeddep"),
    ]
)
```
