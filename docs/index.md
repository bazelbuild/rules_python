# Python Rules for Bazel

`rules_python` is the home for 4 major components:
* the core Python rules -- `py_library`, `py_binary`, `py_test`,
  `py_proto_library`, and related symbols that provide the basis for Python
  support in Bazel.

  This is subject to our breaking change policy outlined in the <support>.
* Package installation rules for integrating with PyPI and other SimpleAPI
  complying indexes.

  This is still `experimental` and the APIs might change more often than the
  core rules or you may experience regressions between the minor releases. In
  that case, please raise tickets to the GH issues bug tracker.
* `sphinxdocs` rules allowing users to generate documentation from bazel or
  Python source code.

  This is available as is and without any guarantees. The semantic versioning
  used by `rules_python` does not apply to bazel rules or the output.
* `gazelle` plugin for generating `BUILD.bazel` files based on Python source
  code.

  This is available as is and without any guarantees. The semantic versioning
  used by `rules_python` does not apply to the plugin.

Documentation for rules_python lives here and in the
[Bazel Build Encyclopedia](https://docs.bazel.build/versions/master/be/python.html).

Examples are in the {gh-path}`examples` directory.

When using bazel 6, the core rules built into the Bazel binary, and the symbols
in this repository are simple aliases. However, on bazel 7 and above starlark
implementation in this repository is used.
See {ref}`Migrating from the Bundled Rules` below.

The core rules are stable. Their implementation in Bazel is subject to Bazel's
[backward compatibility policy](https://docs.bazel.build/versions/master/backward-compatibility.html).
Once migrated to rules_python, they may evolve at a different
rate, but this repository will still follow [semantic versioning](https://semver.org).

The Bazel community maintains this repository. Neither Google nor the Bazel
team provides support for the code. However, this repository is part of the
test suite used to vet new Bazel releases. See {gh-path}`How to contribute
<CONTRIBUTING.md>` for information on our development workflow.

## Bzlmod support

- Status: GA

See {gh-path}`Bzlmod support <BZLMOD_SUPPORT.md>` for any behaviour differences between
`bzlmod` and `WORKSPACE`.

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
