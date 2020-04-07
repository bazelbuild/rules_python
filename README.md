# Python Rules for Bazel

* Postsubmit [![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg?branch=master)](https://buildkite.com/bazel/python-rules-python-postsubmit)
* Postsubmit + Current Bazel Incompatible Flags [![Build status](https://badge.buildkite.com/219007166ab6a7798b22758e7ae3f3223001398ffb56a5ad2a.svg?branch=master)](https://buildkite.com/bazel/rules-python-plus-bazelisk-migrate)

## Recent updates

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

The packaging rules (`pip_import`, etc.) are less stable. We may make breaking
changes as they evolve. There are no guarantees for rules underneath the
`experimental/` directory.

This repository is maintained by the Bazel community. Neither Google, nor the
Bazel team provides support for the code. However, this repository is part of
the test suite used to vet new Bazel releases. See the [How to
contribute](CONTRIBUTING.md) page for information on our development workflow.

## Getting started

To import rules_python in your project, you first need to add it to your
`WORKSPACE` file. If you are using the [Bazel
Federation](https://github.com/bazelbuild/bazel-federation), you just need to
[import the Federation](https://github.com/bazelbuild/bazel-federation#example-workspace)
and call the rules_python setup methods:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_federation",
    url = "https://github.com/bazelbuild/bazel-federation/releases/download/0.0.1/bazel_federation-0.0.1.tar.gz",
    sha256 = "506dfbfd74ade486ac077113f48d16835fdf6e343e1d4741552b450cfc2efb53",
)

load("@bazel_federation//:repositories.bzl", "rules_python_deps")

rules_python_deps()
load("@bazel_federation//setup:rules_python.bzl",  "rules_python_setup")
rules_python_setup(use_pip=True)
```

Note the `use_pip` argument: rules_python may be imported either with or
without support for the packaging rules.

If you are not using the Federation, you can simply import rules_python
directly and call its initialization methods as follows:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_python",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.0.1/rules_python-0.0.1.tar.gz",
    sha256 = "aa96a691d3a8177f3215b14b0edc9641787abaaa30363a080165d06ab65e1161",
)
load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()
# Only needed if using the packaging rules.
load("@rules_python//python:pip.bzl", "pip_repositories")
pip_repositories()
```

To depend on a particular unreleased version (not recommended), you can
use `git_repository` instead of `http_archive`:

```python
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    # NOT VALID: Replace with actual Git commit SHA.
    commit = "{HEAD}",
)

# Then load and call py_repositories() and possibly pip_repositories() as
# above.
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

Adding pip dependencies to your `WORKSPACE` is a two-step process. First you
declare the central repository using `pip_import`, which invokes pip to read
a `requirements.txt` file and download the appropriate wheels. Then you load
the `pip_install` function from the central repo, and call it to create the
individual wheel repos.

**Important:** If you are using Python 3, load and call `pip3_import` instead.

```python
load("@rules_python//python:pip.bzl", "pip_import")

# Create a central repo that knows about the dependencies needed for
# requirements.txt.
pip_import(   # or pip3_import
   name = "my_deps",
   requirements = "//path/to:requirements.txt",
)

# Load the central repo's install function from its `//:requirements.bzl` file,
# and call it.
load("@my_deps//:requirements.bzl", "pip_install")
pip_install()
```

Note that since pip is executed at WORKSPACE-evaluation time, Bazel has no
information about the Python toolchain and cannot enforce that the interpreter
used to invoke pip matches the interpreter used to run `py_binary` targets. By
default, `pip_import` uses the system command `"python"`, which on most
platforms is a Python 2 interpreter. This can be overridden by passing the
`python_interpreter` attribute to `pip_import`. `pip3_import` just acts as a
wrapper that sets `python_interpreter` to `"python3"`.

You can have multiple `pip_import`s in the same workspace, e.g. for Python 2
and Python 3. This will create multiple central repos that have no relation to
one another, and may result in downloading the same wheels multiple times.

As with any repository rule, if you would like to ensure that `pip_import` is
reexecuted in order to pick up a non-hermetic change to your environment (e.g.,
updating your system `python` interpreter), you can completely flush out your
repo cache with `bazel clean --expunge`.

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
        requirement("anohter_pip_dep[some_extra]"),
    ]
)
```

For reference, the wheel repos are canonically named following the pattern:
`@{central_repo_name}_pypi__{distribution}_{version}`. Characters in the
distribution and version that are illegal in Bazel label names (e.g. `-`, `.`)
are replaced with `_`. While this naming pattern doesn't change often, it is
not guaranted to remain stable, so use of the `requirement()` function is
recommended.

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
