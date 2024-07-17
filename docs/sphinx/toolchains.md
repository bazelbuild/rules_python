:::{default-domain} bzl
:::

# Configuring Python toolchains and runtimes

This documents how to configure the Python toolchain and runtimes for different
use cases.

## Bzlmod MODULE configuration

How to configure `rules_python` in your MODULE.bazel file depends on how and why
you're using Python. There are 4 basic use cases:

1. A root module that always uses Python. For example, you're building a
   Python application.
2. A library module with dev-only uses of Python. For example, a Java project
   that only uses Python as part of testing itself.
3. A library module without version constraints. For example, a rule set with
   Python build tools, but defers to the user as to what Python version is used
   for the tools.
4. A library module with version constraints. For example, a rule set with
   Python build tools, and the module requires a specific version of Python
   be used with its tools.

### Root modules

Root modules are always the top-most module. These are special in two ways:

1. Some `rules_python` bzlmod APIs are only respected by the root module.
2. The root module can force module overrides and specific module dependency
   ordering.

When configuring `rules_python` for a root module, you typically want to
explicitly specify the Python version you want to use. This ensures that
dependencies don't change the Python version out from under you. Remember that
`rules_python` will set a version by default, but it will change regularly as
it tracks a recent Python version.

NOTE: If your root module only uses Python for development of the module itself,
you should read the dev-only library module section.

```
bazel_dep(name="rules_python", version=...)
python = use_extension("@rules_python//python/extensions:python.bzl", "python")

python.toolchain(python_version = "3.12", is_default = True)
```

### Library modules

A library module is a module that can show up in arbitrary locations in the
bzlmod module graph -- it's unknown where in the breadth-first search order the
module will be relative to other modules. For example, `rules_python` is a
library module.

#### Library modules with dev-only Python usage

A library module with dev-only Python usage is usually one where Python is only
used as part of its tests. For example, a module for Java rules might run some
Python program to generate test data, but real usage of the rules don't need
Python to work. To configure this, follow the root-module setup, but remember to
specify `dev_dependency = True` to the bzlmod APIs:

```
# MODULE.bazel
bazel_dep(name = "rules_python", version=..., dev_dependency = True)

python = use_extension(
    "@rules_python//python/extensions:python.bzl",
    "python",
    dev_dependency = True
)

python.toolchain(python_version = "3.12", is_default=True)
```

#### Library modules without version constraints

A library module without version constraints is one where the version of Python
used for the Python programs it runs isn't chosen by the module itself. Instead,
it's up to the root module to pick an appropriate version of Python.

For this case, configuration is simple: just depend on `rules_python` and use
the normal `//python:py_binary.bzl` et al rules. There is no need to call
`python.toolchain` -- rules_python ensures _some_ Python version is available,
but more often the root module will specify some version.

```
# MODULE.bazel
bazel_dep(name = "rules_python", version=...)
```

#### Library modules with version constraints

A library module with version constraints is one where the module requires a
specific Python version be used with its tools. This has some pros/cons:

* It allows the library's tools to use a different version of Python than
  the rest of the build. For example, a user's program could use Python 3.12,
  while the library module's tools use Python 3.10.
* It reduces the support burden for the library module because the library only needs
  to test for the particular Python version they intend to run as.
* It raises the support burden for the library module because the version of
  Python being used needs to be regularly incremented.
* It has higher build overhead because additional runtimes and libraries need
  to be downloaded, and Bazel has to keep additional configuration state.

To configure this, request the Python versions needed in MODULE.bazel and use
the version-aware rules for `py_binary`.

```
# MODULE.bazel
bazel_dep(name = "rules_python", version=...)

python = use_extension("@rules_python//python/extensions:python.bzl", "python")
python.toolchain(python_version = "3.12")

# BUILD.bazel
load("@python_versions//3.12:defs.bzl", "py_binary")

py_binary(...)
```

### Pinning to a Python version

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

### Other toolchain details

The `python.toolchain()` call makes its contents available under a repo named
`python_X_Y`, where X and Y are the major and minor versions. For example,
`python.toolchain(python_version="3.11")` creates the repo `@python_3_11`.
Remember to call `use_repo()` to make repos visible to your module:
`use_repo(python, "python_3_11")`

#### Toolchain usage in other rules

Python toolchains can be utilized in other bazel rules, such as `genrule()`, by adding the `toolchains=["@rules_python//python:current_py_toolchain"]` attribute. You can obtain the path to the Python interpreter using the `$(PYTHON2)` and `$(PYTHON3)` ["Make" Variables](https://bazel.build/reference/be/make-variables). See the
{gh-path}`test_current_py_toolchain <tests/load_from_macro/BUILD.bazel>` target for an example.


## Workspace configuration

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

### Workspace toolchain registration

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

## Autodetecting toolchain

The autodetecting toolchain is a deprecated toolchain that is built into Bazel.
It's name is a bit misleading: it doesn't autodetect anything. All it does is
use `python3` from the environment a binary runs within. This provides extremely
limited functionality to the rules (at build time, nothing is knowable about
the Python runtime).

Bazel itself automatically registers `@bazel_tools//tools/python:autodetecting_toolchain`
as the lowest priority toolchain. For WORKSPACE builds, if no other toolchain
is registered, that toolchain will be used. For bzlmod builds, rules_python
automatically registers a higher-priority toolchain; it won't be used unless
there is a toolchain misconfiguration somewhere.

To aid migration off the Bazel-builtin toolchain, rules_python provides
{obj}`@rules_python//python/runtime_env_toolchains:all`. This is an equivalent
toolchain, but is implemented using rules_python's objects.
