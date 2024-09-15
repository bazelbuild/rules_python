# Python Rules for Bazel

rules_python is the home of the core Python rules -- `py_library`,
`py_binary`, `py_test`, `py_proto_library`, and related symbols that provide the basis for Python
support in Bazel. It also contains package installation rules for integrating with PyPI and other indices.

Documentation for rules_python lives here and in the
[Bazel Build Encyclopedia](https://docs.bazel.build/versions/master/be/python.html).

Examples are in the {gh-path}`examples` directory.

Currently, the core rules build into the Bazel binary, and the symbols in this
repository are simple aliases. However, we are migrating the rules to Starlark and removing them from the Bazel binary. Therefore, the future-proof way to depend on Python rules is via this repository. See
{ref}`Migrating from the Bundled Rules` below.

The core rules are stable. Their implementation in Bazel is subject to Bazel's
[backward compatibility policy](https://docs.bazel.build/versions/master/backward-compatibility.html).
Once migrated to rules_python, they may evolve at a different
rate, but this repository will still follow [semantic versioning](https://semver.org).

The Bazel community maintains this repository. Neither Google nor the Bazel team provides support for the code. However, this repository is part of the test suite used to vet new Bazel releases. See
{gh-path}`How to contribute <CONTRIBUTING.md>` for information on our development workflow.

## Bzlmod support

- Status: Beta
- Full Feature Parity: No

See {gh-path}`Bzlmod support <BZLMOD_SUPPORT.md>` for more details

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
started](getting-started).

Note that Starlark-defined bundled symbols underneath
`@bazel_tools//tools/python` are also deprecated. These are not yet rewritten
by buildifier.


```{toctree}
:hidden:
self
getting-started
pypi-dependencies
Toolchains <toolchains>
pip
coverage
precompiling
gazelle
Contributing <contributing>
support
Changelog <changelog>
api/index
environment-variables
Sphinxdocs <sphinxdocs/index>
glossary
genindex
```
