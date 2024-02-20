# Getting started

The following two sections cover using `rules_python` with bzlmod and
the older way of configuring bazel with a `WORKSPACE` file.


## Using bzlmod

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

### Toolchain registration with bzlmod

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

#### Configuring and using the default Python version

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

#### Pinning to a Python version

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

For more documentation, see the bzlmod examples under the {gh-path}`examples`
folder.  Look for the examples that contain a `MODULE.bazel` file.

#### Other toolchain details

The `python.toolchain()` call makes its contents available under a repo named
`python_X_Y`, where X and Y are the major and minor versions. For example,
`python.toolchain(python_version="3.11")` creates the repo `@python_3_11`.
Remember to call `use_repo()` to make repos visible to your module:
`use_repo(python, "python_3_11")`

## Using a WORKSPACE file

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

### Toolchain registration

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
You may also find some quirks while using this toolchain. Please refer to [python-build-standalone documentation's _Quirks_ section](https://gregoryszorc.com/docs/python-build-standalone/main/quirks.html).

## Toolchain usage in other rules

Python toolchains can be utilized in other bazel rules, such as `genrule()`, by adding the `toolchains=["@rules_python//python:current_py_toolchain"]` attribute. You can obtain the path to the Python interpreter using the `$(PYTHON2)` and `$(PYTHON3)` ["Make" Variables](https://bazel.build/reference/be/make-variables). See the
{gh-path}`test_current_py_toolchain <tests/load_from_macro/BUILD.bazel>` target for an example.

## "Hello World"

Once you've imported the rule set into your `WORKSPACE` using any of these
methods, you can then load the core rules in your `BUILD` files with the following:

```starlark
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
  name = "main",
  srcs = ["main.py"],
)
```
