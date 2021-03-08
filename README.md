# Python Rules for Bazel

* Postsubmit [![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg?branch=master)](https://buildkite.com/bazel/python-rules-python-postsubmit)
* Postsubmit + Current Bazel Incompatible Flags [![Build status](https://badge.buildkite.com/219007166ab6a7798b22758e7ae3f3223001398ffb56a5ad2a.svg?branch=master)](https://buildkite.com/bazel/rules-python-plus-bazelisk-migrate)

## Recent updates

* 2020-10-15: Release [`0.1.0` was published](https://github.com/bazelbuild/rules_python/releases/tag/0.1.0), upstreaming
the `pip_install` rule functionality from [github.com/dillon-giacoppo/rules_python_external](https://github.com/dillon-giacoppo/rules_python_external)
to address a number of long-standing issues with `pip_import` (eg. [#96](https://github.com/bazelbuild/rules_python/issues/96), [#71](https://github.com/bazelbuild/rules_python/issues/71), [#102](https://github.com/bazelbuild/rules_python/issues/102)).
Note that this is a backwards-incompatible release on account of the removal of `pip_import` from `@rules_python//python:pip.bzl`.  

* 2019-11-15: Added support for `pip3_import` (and more generally, a
`python_interpreter` attribute to `pip_import`). The canonical naming for wheel
repositories has changed to accomodate loading wheels for both `pip_import` and
`pip3_import` in the same build. To avoid breakage, please use `requirement()`
instead of depending directly on wheel repo labels.

* 2019-07-26: The canonical name of this repo has been changed from
`@io_bazel_rules_python` to just `@rules_python`, in accordance with
[convention](https://docs.bazel.build/versions/master/skylark/deploying.html#workspace).
Please update your `WORKSPACE` file and labels that reference this repo
accordingly.

## Overview

This repository is the home of the core Python rules -- `py_library`,
`py_binary`, `py_test`, and related symbols that provide the basis for Python
support in Bazel. It also contains packaging rules for integrating with PyPI
(`pip`). Documentation lives in the
[`docs/`](https://github.com/bazelbuild/rules_python/tree/master/docs)
directory and in the
[Bazel Build Encyclopedia](https://docs.bazel.build/versions/master/be/python.html).

Currently the core rules are bundled with Bazel itself, and the symbols in this
repository are simple aliases. However, in the future the rules will be
migrated to Starlark and debundled from Bazel. Therefore, the future-proof way
to depend on Python rules is via this repository. See[`Migrating from the Bundled Rules`](#Migrating-from-the-bundled-rules) below.

The core rules are stable. Their implementation in Bazel is subject to Bazel's
[backward compatibility policy](https://docs.bazel.build/versions/master/backward-compatibility.html).
Once they are fully migrated to rules_python, they may evolve at a different
rate, but this repository will still follow
[semantic versioning](https://semver.org).

The packaging rules (`pip_install`, etc.) are less stable. We may make breaking
changes as they evolve. There are no guarantees for rules underneath the
`experimental/` directory.

This repository is maintained by the Bazel community. Neither Google, nor the
Bazel team, provides support for the code. However, this repository is part of
the test suite used to vet new Bazel releases. See the [How to
contribute](CONTRIBUTING.md) page for information on our development workflow.

## Getting started

To import rules_python in your project, you first need to add it to your
`WORKSPACE` file:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_python",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.1.0/rules_python-0.1.0.tar.gz",
    sha256 = "b6d46438523a3ec0f3cead544190ee13223a52f6a6765a29eae7b7cc24cc83a0",
)
```

To depend on a particular unreleased version (not recommended), you can do:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

rules_python_version = "c8c79aae9aa1b61d199ad03d5fe06338febd0774" # Latest @ 2020-10-15

http_archive(
    name = "rules_python",
    sha256 = "5be9610a959772697f57ec66bb58c8132970686ed7fb0f1cf81b22ddf12f5368",
    strip_prefix = "rules_python-{}".format(rules_python_version),
    url = "https://github.com/bazelbuild/rules_python/archive/{}.zip".format(rules_python_version),
)
```

Once you've imported the rule set into your `WORKSPACE` using any of these
methods, you can then load the core rules in your `BUILD` files with:

``` python
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
  name = "main",
  srcs = ["main.py"],
)
```

## Using the packaging rules

The packaging rules create two kinds of repositories: A central repo that holds
downloaded wheel files, and individual repos for each wheel's extracted
contents. Users only need to interact with the central repo; the wheel repos
are essentially an implementation detail. The central repo provides a
`WORKSPACE` macro to create the wheel repos, as well as a function to call in
`BUILD` files to translate a pip package name into the label of a `py_library`
target in the appropriate wheel repo.

### Importing `pip` dependencies

To add pip dependencies to your `WORKSPACE` load
the `pip_install` function, and call it to create the
individual wheel repos.


```python
load("@rules_python//python:pip.bzl", "pip_install")

# Create a central repo that knows about the dependencies needed for
# requirements.txt.
pip_install(
   name = "my_deps",
   requirements = "//path/to:requirements.txt",
)
```

Note that since pip is executed at WORKSPACE-evaluation time, Bazel has no
information about the Python toolchain and cannot enforce that the interpreter
used to invoke pip matches the interpreter used to run `py_binary` targets. By
default, `pip_install` uses the system command `"python3"`. This can be overridden by passing the
`python_interpreter` attribute or `python_interpreter_target` attribute to `pip_install`.

You can have multiple `pip_install`s in the same workspace, e.g. for Python 2
and Python 3. This will create multiple central repos that have no relation to
one another, and may result in downloading the same wheels multiple times.

As with any repository rule, if you would like to ensure that `pip_install` is
re-executed in order to pick up a non-hermetic change to your environment (e.g.,
updating your system `python` interpreter), you can completely flush out your
repo cache with `bazel clean --expunge`.

### Importing `pip` dependencies incrementally (experimental)

One pain point with `pip_install` is the need to download all dependencies resolved by
your requirements.txt before the bazel analysis phase can start. For large python monorepos
this can take a long time, especially on slow connections.

To download only the pip packages needed to build targets in the
subgraph of top level targets in your bazel invocation, you can experiment with using `pip_install_incremental`.
The interface of `pip_install_incremental` mirrors `pip_install` as closely as possible.

The only user facing difference between `pip_install` and `pip_install_incremental` is that for the latter you need
to supply a fully resolved and pinned requirements_lock.txt file (named to distinguish it from requirments.txt
used in `pip_install`). The `requirements` attribute is replaced with a `requirements_lock` attribute to make it
clear that a fully pinned transitive resolve is needed.

To add incremental pip dependencies to your `WORKSPACE` load
the `pip_install_incremental` function, and call it to create a main
repo which contains a macro called `install_deps()` which is used
to create child repos for each package in your requirements_lock.txt.


```python
load("@rules_python//python:pip.bzl", "pip_install_incremental")

# Create a central repo that knows about the dependencies needed for
# requirements.txt.
pip_install(
   name = "my_deps",
   requirements_lock = "//path/to:requirements_lock.txt",
)

load("@my_deps//:requirements.bzl", "install_deps")
install_deps()
```

### Importing `pip` dependencies with `pip_import` (legacy)

The deprecated `pip_import` can still be used if needed.

```
load("@rules_python//python/legacy_pip_import:pip.bzl", "pip_import", "pip_repositories")

# Create a central repo that knows about the dependencies needed for requirements.txt.
pip_import(   # or pip3_import
   name = "my_deps",
   requirements = "//path/to:requirements.txt",
)

# Load the central repo's install function from its `//:requirements.bzl` file, and call it.
load("@my_deps//:requirements.bzl", "pip_install")
pip_install()
```

An example can be found in [`examples/legacy_pip_import](examples/legacy_pip_import).

### Consuming `pip` dependencies

Each extracted wheel repo contains a `py_library` target representing the
wheel's contents. Rather than depend on this target's label directly -- which
would require hardcoding the wheel repo's mangled name into your BUILD files --
you should instead use the `requirement()` function defined in the central
repo's `//:requirements.bzl` file. This function maps a pip package name to a
label. (["Extras"](
https://packaging.python.org/tutorials/installing-packages/#installing-setuptools-extras)
can be referenced using the `pkg[extra]` syntax.)

```python
load("@my_deps//:requirements.bzl", "requirement")

py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        ":myotherlib",
        requirement("some_pip_dep"),
        requirement("another_pip_dep[some_extra]"),
    ]
)
```

For reference, the wheel repos are canonically named following the pattern:
`@{central_repo_name}_pypi__{distribution}_{version}`. Characters in the
distribution and version that are illegal in Bazel label names (e.g. `-`, `.`)
are replaced with `_`. While this naming pattern doesn't change often, it is
not guaranted to remain stable, so use of the `requirement()` function is
recommended.

### Consuming Wheel Dists Directly

If you need to depend on the wheel dists themselves, for instance to pass them	
to some other packaging tool, you can get a handle to them with the `whl_requirement` macro. For example:
	
```python
filegroup(	
    name = "whl_files",	
    data = [	
        whl_requirement("boto3"),	
    ]	
)
```

## Migrating from the bundled rules

The core rules are currently available in Bazel as built-in symbols, but this
form is deprecated. Instead, you should depend on rules_python in your
`WORKSPACE` file and load the Python rules from
`@rules_python//python:defs.bzl`.

A [buildifier](https://github.com/bazelbuild/buildtools/blob/master/buildifier/README.md)
fix is available to automatically migrate `BUILD` and `.bzl` files to add the
appropriate `load()` statements and rewrite uses of `native.py_*`.

```sh
# Also consider using the -r flag to modify an entire workspace.
buildifier --lint=fix --warnings=native-py <files>
```

Currently the `WORKSPACE` file needs to be updated manually as per [Getting
started](#Getting-started) above.

Note that Starlark-defined bundled symbols underneath
`@bazel_tools//tools/python` are also deprecated. These are not yet rewritten
by buildifier.
