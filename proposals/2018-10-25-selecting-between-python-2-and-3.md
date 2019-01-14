---
title: Selecting Between Python 2 and 3
status: Accepted
created: 2018-10-25
updated: 2019-01-11
authors:
  - [brandjon@](https://github.com/brandjon)
reviewers:
  - [mrovner@](https://github.com/mrovner)
discussion thread: [bazel #6583](https://github.com/bazelbuild/bazel/issues/6583)
---

# Selecting Between Python 2 and 3

## Abstract

The "Python mode" configuration value controls whether Python 2 or Python 3 is used to run Python targets built by Bazel. This design document reviews the existing mechanisms for setting the Python mode (the "tri-state model") and describes a simplified mechanism that should replace it (the "boolean model").

Links to Github issues are given where applicable. See also [bazel #6444](https://github.com/bazelbuild/bazel/issues/6444) for a tracking list of Python mode issues.

Throughout, when we say `py_binary`, we also mean to include `py_test`.

## Background

The Python mode controls whether a Python 2 or 3 interpreter is used to run a `py_binary` that is built by Bazel.

* When no `py_runtime` is supplied (via `--python_top`), the mode should control whether the command `python2` or `python3` is embedded into the generated wrapper script ([bazel #4815](https://github.com/bazelbuild/bazel/issues/4815)).

* In a future design for a "`py_toolchain`"-type rule, a pair of interpreter targets will be bundled together as a toolchain, and the mode will control which one gets their full path embedded into this script.

The Python mode is also used to help validate that Python source code annotated with `srcs_version` is used appropriately: If a Python target has the `srcs_version` attribute set to `PY2` or `PY3` rather than to `PY2AND3` (the default), it can only be depended on by targets built in Python 2 or Python 3 mode respectively.

Whenever the same Bazel target can be built in multiple configurations within a single build, it is necessary to write the output artifacts of different versions of the target to different paths. Otherwise the build fails with an "action conflict" error -- Bazel's way of avoiding a correctness bug. For Python targets, and more broadly for targets that may transitively depend on Python targets, this means that different output path roots must be used for different Python modes.

## Out-of-scope generalizations

It is possible to imagine extending the Python mode and `srcs_version` so that it can check for compatibility with minor releases (ex: "Python 3.7"), patch releases ("Python 3.7.1"), alternative interpreters ("CPython" or "PyPy"), and exclude known bad releases. We decline to do so because this treads into generalized constraint checking, which may be better handled in the future by the [platforms and toolchain framework](https://docs.bazel.build/versions/master/toolchains.html).

Compared to these other kinds of version checks, Python 2 vs. 3 is a more compelling use case to support with dedicated machinery. The incompatibilities between these versions are more severe. In many code bases there is an ongoing effort to migrate from 2 to 3, while in others there exists Python 2 code that will never be migrated and must be supported indefinitely.

## Tri-state model

Under the existing tri-state model, the Python mode can take on three values: `PY2`, `PY3`, and `null`. The first two modes can be triggered by the `--force_python` flag on the command line or by the `default_python_version` attribute on `py_binary` rules. The `null` mode is the default state when neither the flag nor `default_python_version` is specified. `select()` expressions can distinguish between these states by using `config_setting`s that test the value of `force_python` (where `null` is matched by `//conditions:default`).

The Python mode is "sticky"; once it is set to `PY2` or `PY3`, it stays that way for all subsequent targets. For a `py_binary` target, this means that all transitive dependencies of the target are built with the same mode as the target itself. For the `--force_python` flag, this means that if the flag is given, it applies universally to the entire build invocation, regardless of the `default_python_version` attributes of any Python targets (hence the "default" in the attribute's name).

### Data dependencies

In principle the Python mode needs to propagate to any `py_library` targets that are transitively in the `deps` attribute. Conceptually, this corresponds to enforcing that a Python binary cannot `import` a module written for a different version of Python than the currently running interpreter. But there is no need to propagate the mode across the `data` attribute, which often corresponds to one Python binary calling another as a separate process.

In order to facilitate `PY3` binaries that depend on `PY2` ones and vice versa, the tri-state model needs to be modified so that the mode is reset to `null` for `data` attributes ([bazel #6441](https://github.com/bazelbuild/bazel/issues/6441)). But it's not clear exactly which attributes should trigger a reset. For example, suppose a Python source file is generated by a `genrule`: Then the `genrule` shouldn't propagate any Python mode to any of its attributes, even though it appears in the transitive closure of a `py_binary`'s `deps`. One could imagine resetting the mode across every attribute except those in a small whitelist (`deps` of `py_binary`, `py_test`, and `py_library`), but this would require new functionality in Bazel and possibly interact poorly with Starlark-defined rules.

### Output roots

Since targets that are built for Python 3 produce different results than those built for Python 2, the outputs for these two configurations must be kept separate in order to avoid action conflicts. Therefore, targets built in `PY3` mode get placed under an output root that includes the string "`-py3`".

Currently, targets that are built in the `null` mode default to using Python 2. Counterintuitively, there is a subtle distinction between building a target in `null` mode and `PY2` mode: Even though the same interpreter is used for the top-level target, the target's transitive dependencies may behave differently, for instance if a `select()` on `force_python` is used. This means that using both `PY2` and `null` for the same target can result in action conflicts ([bazel #6501](https://github.com/bazelbuild/bazel/issues/6501)). However, due to a bug it is not yet possible to have both `PY2` and `null` modes within the same build invocation.

Under the tri-state model, the most straightforward solution for these action conflicts is to use a separate "`-py2`" root for `PY2` mode. This would mean that the same target could be built in not two but three different configurations, corresponding to the three different modes, even though there are only two distinct Python versions. A more complicated alternative would be to prohibit `select()` from being able to distinguish `null` from `PY2`, in order to help ensure that building an arbitrary target in both of these modes does not succeed with different results.

### Libraries at the top level

Currently the mode is only changed by `--force_python` and by `py_binary`. This means that when you build a `py_library` at the top level (that is, specifying it directly on the build command line) without a `--force_python` flag, the library gets the `null` mode, which means Python 2 by default. This causes an error if the library has `srcs_python` set to `PY3`. This in turn means you cannot run a flagless build command on a wildcard pattern, such as `bazel build :all` or `bazel build ...`, if any of the targets in the package(s) contains a Python 3-only library target. Worse, if there are both a Python 2-only library and a Python 3-only library, even specifying `--force_python` can't make the wildcard build work.

In the tri-state model, this can be addressed by allowing `py_library` to change the mode from `null` to either `PY2` or `PY3` based on whichever version is compatible with its `srcs_version` attribute. This was a proposed fix for [bazel #1446](https://github.com/bazelbuild/bazel/issues/1446).

## Boolean model

Under the boolean model, `null` is eliminated as a valid value for the Python mode. Instead, the mode will immediately default to either `PY2` or `PY3`. The mode is no longer sticky, but changes as needed whenever a new `py_binary` target is reached.

Since there is no longer a third value corresponding to "uncommitted", a target can no longer tell whether it was set to `PY2` mode explicitly (by a flag or a `py_binary`), or if it was set by default because no mode was specified. The current version will be inspectable using `config_setting` to read a setting whose value is always one of `"PY2"` or `"PY3"`.

### Data dependencies

Since `py_binary` will now change the mode as needed, there is no need to explicitly reset the mode to a particular value (`null`) when crossing `data` attributes. Python 3 targets can freely depend on Python 2 targets and vice versa, so long as the dependency is not via the `deps` attribute in a way that violates `srcs_version` validation (see below).

### Output roots

Since there are only two modes, there need only be two output roots. This avoids action conflicts without resorting to creating a redundant third output root, or trying to coerce two similar-but-distinct modes to map onto the same output root.

Since the mode is not being reset across data dependencies, it is possible that compared to the tri-state model, the boolean model causes some data dependencies to be built in two configurations instead of just one. This is considered to be an acceptable tradeoff of the boolean model. Note that there exist other cases where redundant rebuilding occurs regardless of which model we use.

### Libraries at the top level

We want to be able to build a `py_library` at the top level without having to specify the correct mode. At the same time, we still want `srcs_version` to validate that a `py_binary` only depends on `py_library`s that are compatible with its mode. The way to achieve this is to move validation from within the `py_library` rule up to the `py_binary` rule.

We add two new boolean fields to a provider returned by `py_library`. This bools correspond to whether or not there are any Python 2-only and Python 3-only sources (respectively) in the library's transitive closure. It is easy to compute these bits as boolean ORs as the providers are merged. `py_binary` simply checks these bits against its own Python mode.

It is important that when `py_binary` detects a version conflict, the user is given the label of one or more transitive dependencies that introduced the constraint. There are several ways to implement this, such as:

- additional provider fields to propagate context to the error message
- an aspect that traverses the dependencies of the `py_binary`
- emitting warning messages at conflicting `py_library` targets

The choice of which approach to use is outside the scope of this proposal.

It is possible that a library is only ever used by Python 3 binaries, but when the library is built as part of a `bazel build :all` command it gets the Python 2 mode by default. This happens even if the library is annotated with `srcs_version` set to `PY3`. Generally this should cause no harm aside from some repeated build work. In the future we can add the same version attribute that `py_binary` has to `py_library`, so the target definition can be made unambiguous.

Aside from failures due to validation, there is currently a bug whereby building a `PY2` library in `PY3` mode can invoke a stub wrapper that fails ([bazel #1393](https://github.com/bazelbuild/bazel/issues/1393)). We will remove the stub and the behavior that attempted to call it.

## API changes

The attribute `default_python_version` of `py_binary` is renamed to `python_version`. The flag `--force_python` is renamed to `--python_version`. (An alternative naming scheme would have been to use "python_major_version", but this is more verbose and inconsistent with `srcs_version`.)

The Python mode becomes "non-sticky" and `srcs_version` validation becomes less strict. Building a `py_library` target directly will not trigger validation. Building a `py_binary` that depends on a `py_library` having an incompatible version will only fail if the dependency occurs via transitive `deps`, and not when it occurs via other paths such as a `data` dep or a `genrule` that produces a source file.

The `"py"` provider of Python rules gains two new boolean fields, `has_py2_only_sources` and `has_py3_only_sources`. Existing Python rules are updated to set these fields. Dependencies of Python rules that do not have the `"py"` provider, or those fields on that provider, are treated as if the value of the fields is `False`.

A new `select()`-able target is created at `@bazel_tools//tools/python:python_version` to return the current Python mode. It can be used in the `flag_values` attribute of `config_setting` and always equals either `"PY2"` or `"PY3"`. (In the future this flag may be moved out of `@bazel_tools` and into `bazelbuild/rules_python`. It may also be made into a `build_setting` so that it can replace the native `--python_version` flag.) It is disallowed to use `"python_version"` in a `config_setting`.

The flag `--host_force_python` is unaffected by this doc, except that it becomes illegal to use it in a `config_setting`.

## Migration and compatibility

The rollout and migration of the new features are split into two groups, syntactic and semantic.

For syntax, the new `--python_version` flag and `python_version` attribute are available immediately, and behave exactly the same as the old flag and attribute. When both the new and old flags are present on the command line, or both the new and old attributes are present on the same target, the new one takes precedence and the old is ignored. The `@bazel_tools//tools/python:python_version` target is also available unconditionally.

A migration flag `--incompatible_remove_old_python_version_api` makes unavailable the `--force_python` flag and `default_python_version` attribute, and disallows `select()`-ing on `"force_python"` and `"host_force_python"`.

For semantics, a flag `--incompatible_allow_python_version_transitions` makes Bazel use the new non-sticky version transitions and the deferred `srcs_version` validation. This applies regardless of whether the new or old API is used to specify the Python version. The new `"py"` provider fields are created regardless of which flags are given.

Migrating for `--incompatible_remove_old_python_version_api` guarantees that the Python version only ever has two possible values. Migrating for `--incompatible_allow_python_version_transitions` enables data dependencies across different versions of Python. It is recommended to do the API migration first in order to avoid action conflicts.

Strictly speaking, Python 3 support is currently marked "experimental" in documentation, so in theory we may be able to make these changes without introducing new incompatible and experimental flags. However these changes will likely affect many users of the Python rules, so flags would be more user-friendly. Bazel is also transitioning to a policy wherein all experimental APIs must be flag-guarded, regardless of any disclaimers in their documentation.

## Changelog

Date         | Change
------------ | ------
2018-10-25   | Initial version
2018-11-02   | Refine migration path
2018-12-17   | Refine plan for `select()`
2018-12-19   | Refine plan for `select()` again
2019-01-10   | Refine migration path
2019-01-11   | Formal approval and update provider fields
