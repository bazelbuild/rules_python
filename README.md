# Experimental Bazel Python Rules

Status: This is **ALPHA** software.

[![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg)](https://buildkite.com/bazel/python-rules-python-postsubmit)

## Recent updates

* 2019-07-26: The canonical name of this repo has been changed from `@io_bazel_rules_python` to just `@rules_python`, in accordance with [convention](https://docs.bazel.build/versions/master/skylark/deploying.html#workspace). Please update your WORKSPACE file and labels that reference this repo accordingly.

## Rules

### Core Python rules

* [py_library](docs/python.md#py_library)
* [py_binary](docs/python.md#py_binary)
* [py_test](docs/python.md#py_test)
* [py_runtime](docs/python.md#py_runtime)
* [py_runtime_pair](docs/python.md#py_runtime_pair)

### Packaging rules

* [pip_import](docs/pip.md#pip_import)

## Overview

This repository provides two sets of Python rules for Bazel. The core rules
provide the essential library, binary, test, and toolchain rules that are
expected for any language supported in Bazel. The packaging rules provide
support for integration with dependencies that, in a non-Bazel environment,
would typically be managed by `pip`.

Historically, the core rules have been bundled with Bazel itself. The Bazel
team is in the process of transitioning these rules to live in
bazelbuild/rules_python instead. In the meantime, all users of Python rules in
Bazel should migrate their builds to load these rules and their related symbols
(`PyInfo`, etc.) from `@rules_python` instead of using built-ins or
`@bazel_tools//tools/python`.

## Setup

To use this repository, first modify your `WORKSPACE` file to load it and call
the initialization functions as needed:

```python
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    # NOT VALID!  Replace this with a Git commit SHA.
    commit = "{HEAD}",
)

# This call should always be present.
load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()

# This one is only needed if you're using the packaging rules.
load("@rules_python//python:pip.bzl", "pip_repositories")
pip_repositories()
```

Then in your `BUILD` files, load the core rules as needed with:

``` python
load("@rules_python//python:defs.bzl", "py_binary")

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

## Development

### Documentation

All of the content under `docs/` besides the `BUILD` file is generated with
Stardoc. To regenerate the documentation, simply run

```shell
./update_docs.sh
```

from the repository root.

### Precompiled par files

The `piptool.par` and `whltool.par` files underneath `tools/` are compiled
versions of the Python scripts under the `rules_python/` directory. We need to
check in built artifacts because they are executed during `WORKSPACE`
evaluation, before Bazel itself is able to build anything from source.

The .par files need to be regenerated whenever their sources are updated. This
can be done by running

```shell
./update_tools.sh
```

from the repository root. However, since these files contain compiled code,
we do not accept commits that modify them from untrusted sources. If you submit
a pull request that modifies the sources and we accept the changes, we will
regenerate these files for you before merging.
