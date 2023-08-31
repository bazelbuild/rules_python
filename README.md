# Python Rules for Bazel

[![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg?branch=main)](https://buildkite.com/bazel/rules-python-python)

## Overview

This repository is the home of the core Python rules -- `py_library`,
`py_binary`, `py_test`, `py_proto_library`, and related symbols that provide the basis for Python
support in Bazel. It also contains package installation rules for integrating with PyPI and other indices. 

Documentation for rules_python  lives in the
[`docs/`](https://github.com/bazelbuild/rules_python/tree/main/docs)
directory and in the
[Bazel Build Encyclopedia](https://docs.bazel.build/versions/master/be/python.html).

Examples live in the [examples](examples) directory.

Currently, the core rules build into the Bazel binary, and the symbols in this
repository are simple aliases. However, we are migrating the rules to Starlark and removing them from the Bazel binary. Therefore, the future-proof way to depend on Python rules is via this repository. See[`Migrating from the Bundled Rules`](#Migrating-from-the-bundled-rules) below.

The core rules are stable. Their implementation in Bazel is subject to Bazel's
[backward compatibility policy](https://docs.bazel.build/versions/master/backward-compatibility.html).
Once migrated to rules_python, they may evolve at a different
rate, but this repository will still follow [semantic versioning](https://semver.org).

The Bazel community maintains this repository. Neither Google nor the Bazel team provides support for the code. However, this repository is part of the test suite used to vet new Bazel releases. See [How to contribute](CONTRIBUTING.md) page for information on our development workflow.

## Bzlmod support

- Status: Beta
- Full Feature Parity: No

See [Bzlmod support](BZLMOD_SUPPORT.md) for more details.

## Getting started

The following two sections cover using `rules_python` with bzlmod and
the older way of configuring bazel with a `WORKSPACE` file.

### Using bzlmod

**IMPORTANT: bzlmod support is still in Beta; APIs are subject to change.**

The first step to using rules_python with bzlmod is to add the dependency to
your MODULE.bazel file:

```starlark
# Update the version "0.0.0" to the release found here:
# https://github.com/bazelbuild/rules_python/releases.
bazel_dep(name = "rules_python", version = "0.0.0")
```

Once added, you can load the rules and use them:

```starlark
load("@rules_python//python:py_binary.bzl", "py_binary")

py_binary(...)
```

Depending on what you're doing, you likely want to do some additional
configuration to control what Python version is used; read the following
sections for how to do that.

#### Toolchain registration with bzlmod

A default toolchain is automatically configured depending on
`rules_python`. Note, however, the version used tracks the most recent Python
release and will change often.

If you want to use a specific Python version for your programs, then how
to do so depends on if you're configuring the root module or not. The root
module is special because it can set the *default* Python version, which
is used by the version-unaware rules (e.g. `//python:py_binary.bzl` et al). For
submodules, it's recommended to use the version-aware rules to pin your programs
to a specific Python version so they don't accidentally run with a different
version configured by the root module.

##### Configuring and using the default Python version

To specify what the default Python version is, set `is_default = True` when
calling `python.toolchain()`. This can only be done by the root module; it is
silently ignored if a submodule does it. Similarly, using the version-unaware
rules (which always use the default Python version) should only be done by the
root module. If submodules use them, then they may run with a different Python
version than they expect.

```starlark
python = use_extension("@rules_python//python/extensions:python.bzl", "python")

python.toolchain(
    python_version = "3.11",
    is_default = True,
)
```

Then use the base rules from e.g. `//python:py_binary.bzl`.

##### Pinning to a Python version

Pinning to a version allows targets to force that a specific Python version is
used, even if the root module configures a different version as a default. This
is most useful for two cases:

1. For submodules to ensure they run with the appropriate Python version
2. To allow incremental, per-target, upgrading to newer Python versions,
   typically in a mono-repo situation.

To configure a submodule with the version-aware rules, request the particular
version you need, then use the `@python_versions` repo to use the rules that
force specific versions:

```starlark
python = use_extension("@rules_python//python/extensions:python.bzl", "python")

python.toolchain(
    python_version = "3.11",
)
use_repo(python, "python_versions")
```

Then use e.g. `load("@python_versions//3.11:defs.bzl", "py_binary")` to use
the rules that force that particular version. Multiple versions can be specified
and use within a single build.

For more documentation, see the bzlmod examples under the [examples](examples) folder.  Look for the examples that contain a `MODULE.bazel` file.

##### Other toolchain details

The `python.toolchain()` call makes its contents available under a repo named
`python_X_Y`, where X and Y are the major and minor versions. For example,
`python.toolchain(python_version="3.11")` creates the repo `@python_3_11`.
Remember to call `use_repo()` to make repos visible to your module:
`use_repo(python, "python_3_11")`

### Using a WORKSPACE file

To import rules_python in your project, you first need to add it to your
`WORKSPACE` file, using the snippet provided in the
[release you choose](https://github.com/bazelbuild/rules_python/releases)

To depend on a particular unreleased version, you can do the following:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")


# Update the SHA and VERSION to the lastest version available here:
# https://github.com/bazelbuild/rules_python/releases.

SHA="84aec9e21cc56fbc7f1335035a71c850d1b9b5cc6ff497306f84cced9a769841"

VERSION="0.23.1"

http_archive(
    name = "rules_python",
    sha256 = SHA,
    strip_prefix = "rules_python-{}".format(VERSION),
    url = "https://github.com/bazelbuild/rules_python/releases/download/{}/rules_python-{}.tar.gz".format(VERSION,VERSION),
)

load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()
```

#### Toolchain registration

To register a hermetic Python toolchain rather than rely on a system-installed interpreter for runtime execution, you can add to the `WORKSPACE` file:

```starlark
load("@rules_python//python:repositories.bzl", "python_register_toolchains")

python_register_toolchains(
    name = "python_3_11",
    # Available versions are listed in @rules_python//python:versions.bzl.
    # We recommend using the same version your team is already standardized on.
    python_version = "3.11",
)

load("@python_3_11//:defs.bzl", "interpreter")

load("@rules_python//python:pip.bzl", "pip_parse")

pip_parse(
    ...
    python_interpreter_target = interpreter,
    ...
)
```

After registration, your Python targets will use the toolchain's interpreter during execution, but a system-installed interpreter
is still used to 'bootstrap' Python targets (see https://github.com/bazelbuild/rules_python/issues/691).
You may also find some quirks while using this toolchain. Please refer to [python-build-standalone documentation's _Quirks_ section](https://python-build-standalone.readthedocs.io/en/latest/quirks.html).

### Toolchain usage in other rules

Python toolchains can be utilized in other bazel rules, such as `genrule()`, by adding the `toolchains=["@rules_python//python:current_py_toolchain"]` attribute. You can obtain the path to the Python interpreter using the `$(PYTHON2)` and `$(PYTHON3)` ["Make" Variables](https://bazel.build/reference/be/make-variables). See the [`test_current_py_toolchain`](tests/load_from_macro/BUILD.bazel) target for an example.

### "Hello World"

Once you've imported the rule set into your `WORKSPACE` using any of these
methods, you can then load the core rules in your `BUILD` files with the following:

```starlark
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
  name = "main",
  srcs = ["main.py"],
)
```

## Using dependencies from PyPI

Using PyPI packages (aka "pip install") involves two main steps.

1. [Installing third_party packages](#installing-third_party-packages)
2. [Using third_party packages as dependencies](#using-third_party-packages-as-dependencies

### Installing third_party packages

#### Using bzlmod

To add pip dependencies to your `MODULE.bazel` file, use the `pip.parse` extension, and call it to create the central external repo and individual wheel external repos. Include in the `MODULE.bazel` the toolchain extension as shown in the first bzlmod example above.

```starlark
pip = use_extension("@rules_python//python/extensions:pip.bzl", "pip")
pip.parse(
    hub_name = "my_deps",
    python_version = "3.11",
    requirements_lock = "//:requirements_lock_3_11.txt",
)
use_repo(pip, "my_deps")
```
For more documentation, including how the rules can update/create a requirements file, see the bzlmod examples under the [examples](examples) folder.

#### Using a WORKSPACE file

To add pip dependencies to your `WORKSPACE`, load the `pip_parse` function and call it to create the central external repo and individual wheel external repos.

```starlark
load("@rules_python//python:pip.bzl", "pip_parse")

# Create a central repo that knows about the dependencies needed from
# requirements_lock.txt.
pip_parse(
   name = "my_deps",
   requirements_lock = "//path/to:requirements_lock.txt",
)
# Load the starlark macro, which will define your dependencies.
load("@my_deps//:requirements.bzl", "install_deps")
# Call it to define repos for your requirements.
install_deps()
```

#### pip rules

Note that since `pip_parse` is a repository rule and therefore executes pip at WORKSPACE-evaluation time, Bazel has no
information about the Python toolchain and cannot enforce that the interpreter
used to invoke pip matches the interpreter used to run `py_binary` targets. By
default, `pip_parse` uses the system command `"python3"`. To override this, pass in the
`python_interpreter` attribute or `python_interpreter_target` attribute to `pip_parse`.

You can have multiple `pip_parse`s in the same workspace.  Or use the pip extension multiple times when using bzlmod.
This configuration will create multiple external repos that have no relation to one another 
and may result in downloading the same wheels numerous times.

As with any repository rule, if you would like to ensure that `pip_parse` is
re-executed to pick up a non-hermetic change to your environment (e.g.,
updating your system `python` interpreter), you can force it to re-execute by running
`bazel sync --only [pip_parse name]`.

Note: The `pip_install` rule is deprecated. `pip_parse` offers identical functionality, and both `pip_install` and `pip_parse` now have the same implementation. The name `pip_install` may be removed in a future version of the rules.

The maintainers have made all reasonable efforts to facilitate a smooth transition. Still, some users of `pip_install` will need to replace their existing `requirements.txt` with a fully resolved set of dependencies using a tool such as `pip-tools` or the `compile_pip_requirements` repository rule.

### Using third_party packages as dependencies

Each extracted wheel repo contains a `py_library` target representing
the wheel's contents. There are two ways to access this library. The
first uses the `requirement()` function defined in the central
repo's `//:requirements.bzl` file. This function maps a pip package
name to a label:

```starlark
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
stable. Using `requirement()` ensures you do not have to refactor
your `BUILD` files if the pattern changes.

On the other hand, using `requirement()` has several drawbacks; see
[this issue][requirements-drawbacks] for an enumeration. If you don't
want to use `requirement()`, you can use the library
labels directly instead. For `pip_parse`, the labels are of the following form:

```starlark
@{name}_{package}//:pkg
```

Here `name` is the `name` attribute that was passed to `pip_parse` and
`package` is the pip package name with characters that are illegal in
Bazel label names (e.g. `-`, `.`) replaced with `_`. If you need to
update `name` from "old" to "new", then you can run the following
buildozer command:

```shell
buildozer 'substitute deps @old_([^/]+)//:pkg @new_${1}//:pkg' //...:*
```

For `pip_install`, the labels are instead of the form:

```starlark
@{name}//pypi__{package}
```

[requirements-drawbacks]: https://github.com/bazelbuild/rules_python/issues/414

#### 'Extras' dependencies

Any 'extras' specified in the requirements lock file will be automatically added as transitive dependencies of the package. In the example above, you'd just put `requirement("useful_dep")`.

### Consuming Wheel Dists Directly

If you need to depend on the wheel dists themselves, for instance, to pass them
to some other packaging tool, you can get a handle to them with the `whl_requirement` macro. For example:

```starlark
filegroup(
    name = "whl_files",
    data = [
        whl_requirement("boto3"),
    ]
)
```
# Python Gazelle plugin

[Gazelle](https://github.com/bazelbuild/bazel-gazelle)
is a build file generator for Bazel projects. It can create new `BUILD.bazel` files for a project that follows language conventions and update existing build files to include new sources, dependencies, and options.

Bazel may run Gazelle using the Gazelle rule, or it may be installed and run as a command line tool.

See the documentation for Gazelle with rules_python [here](gazelle).

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

Currently, the `WORKSPACE` file needs to be updated manually as per [Getting
started](#Getting-started) above.

Note that Starlark-defined bundled symbols underneath
`@bazel_tools//tools/python` are also deprecated. These are not yet rewritten
by buildifier.

