# Bzlmod support

## `rule_python` `bzlmod` support

- Status: Beta
- Full Feature Parity: No

Some features are missing or broken, and the public APIs are not yet stable.

## Configuration

The releases page will give you the latest version number, and a basic example.  The release page is located [here](/bazelbuild/rules_python/releases).

## What is bzlmod?

> Bazel supports external dependencies, source files (both text and binary) used in your build that are not from your workspace. For example, they could be a ruleset hosted in a GitHub repo, a Maven artifact, or a directory on your local machine outside your current workspace.
>
> As of Bazel 6.0, there are two ways to manage external dependencies with Bazel: the traditional, repository-focused WORKSPACE system, and the newer module-focused MODULE.bazel system (codenamed Bzlmod, and enabled with the flag `--enable_bzlmod`). The two systems can be used together, but Bzlmod is replacing the WORKSPACE system in future Bazel releases.
> -- <cite>https://bazel.build/external/overview</cite>

## Examples

We have two examples that demonstrate how to configure `bzlmod`.

The first example is in [examples/bzlmod](examples/bzlmod), and it demonstrates basic bzlmod configuration.
A user does not use `local_path_override` stanza and would define the version in the `bazel_dep` line.

A second example, in [examples/bzlmod_build_file_generation](examples/bzlmod_build_file_generation) demonstrates the use of `bzlmod` to configure `gazelle` support for `rules_python`.

## Feature parity

This rule set does not have full feature partity with the older `WORKSPACE` type configuration:

1. Multiple python versions are not yet supported, as demonstrated in [this](examples/multi_python_versions) example.
2. Gazelle does not support finding deps in sub-modules.  For instance we can have a dep like ` "@our_other_module//other_module/pkg:lib",` in a `py_test` definition.

Check ["issues"](/bazelbuild/rules_python/issues) for an up to date list.
