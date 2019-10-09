# Python Rules for Bazel

## Recent updates

* 2019-07-26: The canonical name of this repo has been changed from `@io_bazel_rules_python` to just `@rules_python`, in accordance with [convention](https://docs.bazel.build/versions/master/skylark/deploying.html#workspace). Please update your WORKSPACE file and labels that reference this repo accordingly.

## Overview

[![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg)](https://buildkite.com/bazel/python-rules-python-postsubmit)

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

## Getting started

To import rules_python in your project, you first need to add it to your
`WORKSPACE` file. If you are using the [Bazel
Federation](https://github.com/bazelbuild/bazel-federation), you will want to
copy the boilerplate in the rules_python release's notes, under the "WORKSPACE
setup" heading. This will look something like the following:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_python",
    # NOT VALID: Replace with actual version and SHA.
    url = "https://github.com/bazelbuild/rules_python/releases/download/<RELEASE>/rules_python-<RELEASE>.tar.gz",
    sha256 = "<SHA>",
)
load("@rules_python//python:repositories.bzl", "py_repositories", "rules_python_toolchains")
py_repositories()
rules_python_toolchains()
```

Otherwise, you may import rules_python in a standalone way by copying the
following:

```python
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
git_repository(
    name = "rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    # NOT VALID: Replace with actual Git commit SHA.
    commit = "{HEAD}",
)
# This call should always be present.
load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()
# This one is only needed if you're using the packaging rules.
load("@rules_python//python:pip.bzl", "pip_repositories")
pip_repositories()
```

Either way, you can then load the core rules in your `BUILD` files with:

``` python
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
  name = "main",
  ...
)
```

## Using the packaging rules

### Importing `pip` dependencies

The packaging rules are designed to have developers continue using
`requirements.txt` to express their dependencies in a Python idiomatic manner.
These dependencies are imported into the Bazel dependency graph via a
two-phased process in `WORKSPACE`:

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

### Consuming `pip` dependencies

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

### Canonical `whl_library` naming

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

## Migrating from the bundled rules

The core rules are currently available in Bazel as built-in symbols, but this
form is deprecated. Instead, you should depend on rules_python in your
WORKSPACE file and load the Python rules from `@rules_python//python:defs.bzl`.

A [buildifier](https://github.com/bazelbuild/buildtools/blob/master/buildifier/README.md)
fix is available to automatically migrate BUILD and .bzl files to add the
appropriate `load()` statements and rewrite uses of `native.py_*`.

```sh
buildifier --lint=fix --warnings=native-py <files>
```

Currently the WORKSPACE file needs to be updated manually as per [Getting
started](#Getting-started) above.

Note that Starlark-defined bundled symbols underneath
`@bazel_tools//tools/python` are also deprecated. These are not yet rewritten
by buildifier.

## Development

### Documentation

The content underneath `docs/` is generated.  To update the documentation,
simply run this in the root of the repository:

```shell
./update_docs.sh
```

### Precompiled .par files

The `piptool.par` and `whltool.par` files underneath `tools/` are compiled
versions of the Python scripts under the `packaging/` directory. We need to
check in built artifacts because they are executed during `WORKSPACE`
evaluation, before Bazel itself is able to build anything from source.

The .par files need to be regenerated whenever their sources are updated. This
can be done by running

```shell
# Optionally pass --nodocker if Docker is not available on your system.
./update_tools.sh
```

from the repository root. However, since these files contain compiled code,
we do not accept commits that modify them from untrusted sources.<sup>1</sup>
If you submit a pull request that modifies the sources and we accept the
changes, we will regenerate these files for you before merging.

<sup>1</sup> See "[Reflections on Trusting Trust](https://en.wikipedia.org/wiki/Backdoor_(computing)#Compiler_backdoors)".
