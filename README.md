# Python Rules for Bazel

* Postsubmit [![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg?branch=main)](https://buildkite.com/bazel/python-rules-python-postsubmit)
* Postsubmit + Current Bazel Incompatible Flags [![Build status](https://badge.buildkite.com/219007166ab6a7798b22758e7ae3f3223001398ffb56a5ad2a.svg?branch=main)](https://buildkite.com/bazel/rules-python-plus-bazelisk-migrate)

## Overview

This repository is the home of the core Python rules -- `py_library`,
`py_binary`, `py_test`, `py_proto_library`, and related symbols that provide the basis for Python
support in Bazel. It also contains package installation rules for integrating with PyPI and other package indices. Documentation lives in the
[`docs/`](https://github.com/bazelbuild/rules_python/tree/main/docs)
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

The package installation rules (`pip_install`, `pip_parse` etc.) are less stable. We may make breaking
changes as they evolve.

This repository is maintained by the Bazel community. Neither Google, nor the
Bazel team, provides support for the code. However, this repository is part of
the test suite used to vet new Bazel releases. See the [How to
contribute](CONTRIBUTING.md) page for information on our development workflow.

## `bzlmod` support

- Status: Beta
- Full Feature Parity: No

See [Bzlmod support](BZLMOD_SUPPORT.md) for more details.

## Getting started

The next two sections cover using `rules_python` with bzlmod and
the older way of configuring bazel with a `WORKSPACE` file.

### Using bzlmod

NOTE: bzlmod support is still experimental; APIs subject to change.

To import rules_python in your project, you first need to add it to your
`MODULE.bazel` file, using the snippet provided in the
[release you choose](https://github.com/bazelbuild/rules_python/releases).

Once the dependency is added, a Python toolchain will be automatically
registered and you'll be able to create runnable programs and tests.


#### Toolchain registration with bzlmod

NOTE: bzlmod support is still experimental; APIs subject to change.

A default toolchain is automatically configured for by depending on
`rules_python`. Note, however, the version used tracks the most recent Python
release and will change often.

If you want to register specific Python versions, then use
`python.toolchain()` for each version you need:

```starlark
python = use_extension("@rules_python//python:extensions.bzl", "python")

python.toolchain(
    python_version = "3.9",
)
```

### Using pip with bzlmod

NOTE: bzlmod support is still experimental; APIs subject to change.

To use dependencies from PyPI, the `pip.parse()` extension is used to
convert a requirements file into Bazel dependencies.

```starlark
python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(
    python_version = "3.9",
)

interpreter = use_extension("@rules_python//python/extensions:interpreter.bzl", "interpreter")
interpreter.install(
    name = "interpreter",
    python_name = "python_3_9",
)
use_repo(interpreter, "interpreter")

pip = use_extension("@rules_python//python/extensions:pip.bzl", "pip")
pip.parse(
    hub_name = "pip",
    python_interpreter_target = "@interpreter//:python",
    requirements_lock = "//:requirements_lock.txt",
    requirements_windows = "//:requirements_windows.txt",
)
use_repo(pip, "pip")
```

For more documentation see the bzlmod examples under the [examples](examples) folder.

### Using a WORKSPACE file

To import rules_python in your project, you first need to add it to your
`WORKSPACE` file, using the snippet provided in the
[release you choose](https://github.com/bazelbuild/rules_python/releases)

To depend on a particular unreleased version, you can do:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

rules_python_version = "740825b7f74930c62f44af95c9a4c1bd428d2c53" # Latest @ 2021-06-23

http_archive(
    name = "rules_python",
    # Bazel will print the proper value to add here during the first build.
    # sha256 = "FIXME",
    strip_prefix = "rules_python-{}".format(rules_python_version),
    url = "https://github.com/bazelbuild/rules_python/archive/{}.zip".format(rules_python_version),
)
```

#### Toolchain registration

To register a hermetic Python toolchain rather than rely on a system-installed interpreter for runtime execution, you can add to the `WORKSPACE` file:

```python
load("@rules_python//python:repositories.bzl", "python_register_toolchains")

python_register_toolchains(
    name = "python3_9",
    # Available versions are listed in @rules_python//python:versions.bzl.
    # We recommend using the same version your team is already standardized on.
    python_version = "3.9",
)

load("@python3_9//:defs.bzl", "interpreter")

load("@rules_python//python:pip.bzl", "pip_parse")

pip_parse(
    ...
    python_interpreter_target = interpreter,
    ...
)
```

After registration, your Python targets will use the toolchain's interpreter during execution, but a system-installed interpreter
is still used to 'bootstrap' Python targets (see https://github.com/bazelbuild/rules_python/issues/691).
You may also find some quirks while using this toolchain. Please refer to [python-build-standalone documentation's _Quirks_ section](https://python-build-standalone.readthedocs.io/en/latest/quirks.html) for details.

### Toolchain usage in other rules

Python toolchains can be utilised in other bazel rules, such as `genrule()`, by adding the `toolchains=["@rules_python//python:current_py_toolchain"]` attribute. The path to the python interpreter can be obtained by using the `$(PYTHON2)` and `$(PYTHON3)` ["Make" Variables](https://bazel.build/reference/be/make-variables). See the [`test_current_py_toolchain`](tests/load_from_macro/BUILD.bazel) target for an example.


### "Hello World"

Once you've imported the rule set into your `WORKSPACE` using any of these
methods, you can then load the core rules in your `BUILD` files with:

``` python
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
  name = "main",
  srcs = ["main.py"],
)
```

## Using the package installation rules

Usage of the packaging rules involves two main steps.

1. [Installing third_party packages](#installing-third_party-packages)
2. [Using third_party packages as dependencies](#using-third_party-packages-as-dependencies)

The package installation rules create two kinds of repositories: A central external repo that holds
downloaded wheel files, and individual external repos for each wheel's extracted
contents. Users only need to interact with the central external repo; the wheel repos
are essentially an implementation detail. The central external repo provides a
`WORKSPACE` macro to create the wheel repos, as well as a function, `requirement()`, for use in
`BUILD` files that translates a pip package name into the label of a `py_library`
target in the appropriate wheel repo.

### Installing third_party packages

#### Using bzlmod

To add pip dependencies to your `MODULE.bazel` file, use the `pip.parse` extension, and call it to create the
central external repo and individual wheel external repos.

```python
pip.parse(
    hub_name = "my_deps",
    requirements_lock = "//:requirements_lock.txt",
)

use_repo(pip, "my_deps")
```

#### Using a WORKSPACE file

To add pip dependencies to your `WORKSPACE`, load the `pip_parse` function, and call it to create the
central external repo and individual wheel external repos.


```python
load("@rules_python//python:pip.bzl", "pip_parse")

# Create a central repo that knows about the dependencies needed from
# requirements_lock.txt.
pip_parse(
   name = "my_deps",
   requirements_lock = "//path/to:requirements_lock.txt",
)
# Load the starlark macro which will define your dependencies.
load("@my_deps//:requirements.bzl", "install_deps")
# Call it to define repos for your requirements.
install_deps()
```

#### pip rules

Note that since `pip_parse` is a repository rule and therefore executes pip at WORKSPACE-evaluation time, Bazel has no
information about the Python toolchain and cannot enforce that the interpreter
used to invoke pip matches the interpreter used to run `py_binary` targets. By
default, `pip_parse` uses the system command `"python3"`. This can be overridden by passing the
`python_interpreter` attribute or `python_interpreter_target` attribute to `pip_parse`.

You can have multiple `pip_parse`s in the same workspace. This will create multiple external repos that have no relation to one another, and may result in downloading the same wheels multiple times.

As with any repository rule, if you would like to ensure that `pip_parse` is
re-executed in order to pick up a non-hermetic change to your environment (e.g.,
updating your system `python` interpreter), you can force it to re-execute by running
`bazel sync --only [pip_parse name]`.

Note: The `pip_install` rule is deprecated. `pip_parse` offers identical functionality and both `pip_install`
and `pip_parse` now have the same implementation. The name `pip_install` may be removed in a future version of the rules.
The maintainers have taken all reasonable efforts to faciliate a smooth transition, but some users of `pip_install` will
need to replace their existing `requirements.txt` with a fully resolved set of dependencies using a tool such as
`pip-tools` or the `compile_pip_requirements` repository rule.

### Using third_party packages as dependencies

Each extracted wheel repo contains a `py_library` target representing
the wheel's contents. There are two ways to access this library. The
first is using the `requirement()` function defined in the central
repo's `//:requirements.bzl` file. This function maps a pip package
name to a label:

```python
load("@my_deps//:requirements.bzl", "requirement")

py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        ":myotherlib",
        requirement("some_pip_dep"),
        requirement("another_pip_dep"),
    ]
)
```

The reason `requirement()` exists is that the pattern for the labels,
while not expected to change frequently, is not guaranteed to be
stable. Using `requirement()` ensures that you do not have to refactor
your `BUILD` files if the pattern changes.

On the other hand, using `requirement()` has several drawbacks; see
[this issue][requirements-drawbacks] for an enumeration. If you don't
want to use `requirement()` then you can instead use the library
labels directly. For `pip_parse` the labels are of the form

```
@{name}_{package}//:pkg
```

Here `name` is the `name` attribute that was passed to `pip_parse` and
`package` is the pip package name with characters that are illegal in
Bazel label names (e.g. `-`, `.`) replaced with `_`. If you need to
update `name` from "old" to "new", then you can run the following
buildozer command:

```
buildozer 'substitute deps @old_([^/]+)//:pkg @new_${1}//:pkg' //...:*
```

For `pip_install` the labels are instead of the form

```
@{name}//pypi__{package}
```

[requirements-drawbacks]: https://github.com/bazelbuild/rules_python/issues/414

#### 'Extras' dependencies

Any 'extras' specified in the requirements lock-file will be automatically added as transitive dependencies of the 
package. In the example above, you'd just put `requirement("useful_dep")`.

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
