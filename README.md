# Experimental Bazel Python Rules

Status: This is **ALPHA** software.

[![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg)](https://buildkite.com/bazel/python-rules-python-postsubmit)

## Recent updates

* 2019-07-26: The canonical name of this repo has been changed from `@io_bazel_rules_python` to just `@rules_python`, in accordance with [convention](https://docs.bazel.build/versions/master/skylark/deploying.html#workspace). Please update your WORKSPACE file and labels that reference this repo accordingly.

## Rules

* [pip_import](docs/python/pip.md#pip_import)
* [pip3_import](docs/python/pip.md#pip3_import)
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
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    # NOT VALID!  Replace this with a Git commit SHA.
    commit = "{HEAD}",
)

# Only needed for PIP support:
load("@rules_python//python:pip.bzl", "pip_repositories")

pip_repositories()
```

Then in your `BUILD` files load the python rules with:

``` python
load(
  "@rules_python//python:defs.bzl",
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
load("@rules_python//python:pip.bzl", "pip_import")

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

The `pip_import` rule uses the system `python` command, which is usually
Python 2. `pip3_import` uses the system `python3` command.

## Consuming `pip` dependencies

Once a set of dependencies has been imported via `pip_import` and `pip_install`
we can start consuming them in our `py_{binary,library,test}` rules.  In support
of this, the generated `requirements.bzl` also contains a `requirement` method,
which can be used directly in `deps=[]` to reference an imported `py_library`.

```python
load("@my_deps//:requirements.bzl", "requirement")

py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        ":myotherlib",
	# This takes the name as specified in requirements.txt
	requirement("importeddep"),
    ]
)
```

## Canonical `whl_library` naming

It is notable that `whl_library` rules imported via `pip_import` are canonically
named, following the pattern: `pypi__{distribution}_{version}`.  Characters in
these components that are illegal in Bazel label names (e.g. `-`, `.`) are
replaced with `_`.

This canonical naming helps avoid redundant work to import the same library
multiple times.  It is expected that this naming will remain stable, so folks
should be able to reliably depend directly on e.g. `@pypi__futures_3_1_1//:pkg`
for dependencies, however, it is recommended that folks stick with the
`requirement` pattern in case the need arises for us to make changes to this
format in the future.

["Extras"](
https://packaging.python.org/tutorials/installing-packages/#installing-setuptools-extras)
will have a target of the extra name (in place of `pkg` above).

## Updating `docs/`

All of the content (except `BUILD`) under `docs/` is generated.  To update the
documentation simply run this in the root of the repository:
```shell
./update_docs.sh
```

## Updating `tools/`

All of the content (except `BUILD`) under `tools/` is generated.  To update the
documentation simply run this in the root of the repository:
```shell
./update_tools.sh
```
