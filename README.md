# Python Rules for Bazel

[![Build status](https://badge.buildkite.com/0bcfe58b6f5741aacb09b12485969ba7a1205955a45b53e854.svg?branch=main)](https://buildkite.com/bazel/rules-python-python)

## Overview

This repository is the home of the core Python rules -- `py_library`,
`py_binary`, `py_test`, `py_proto_library`, and related symbols that provide the basis for Python
support in Bazel. It also contains package installation rules for integrating with PyPI and other indices. 

Documentation for rules_python is at <https://rules-python.readthedocs.io> and in the
[Bazel Build Encyclopedia](https://docs.bazel.build/versions/master/be/python.html).

Examples live in the [examples](examples) directory.

Currently, the core rules build into the Bazel binary, and the symbols in this
repository are simple aliases. However, we are migrating the rules to Starlark and removing them from the Bazel binary. Therefore, the future-proof way to depend on Python rules is via this repository. See[`Migrating from the Bundled Rules`](#Migrating-from-the-bundled-rules) below.

The core rules are stable. Their implementation in Bazel is subject to Bazel's
[backward compatibility policy](https://docs.bazel.build/versions/master/backward-compatibility.html).
Once migrated to rules_python, they may evolve at a different
rate, but this repository will still follow [semantic versioning](https://semver.org).

The Bazel community maintains this repository. Neither Google nor the Bazel team provides support for the code. However, this repository is part of the test suite used to vet new Bazel releases. See [How to contribute](CONTRIBUTING.md) page for information on our development workflow.

## Documentation

For detailed documentation, see <https://rules-python.readthedocs.io>

## Bzlmod support

- Status: Beta
- Full Feature Parity: No

See [Bzlmod support](BZLMOD_SUPPORT.md) for more details.
