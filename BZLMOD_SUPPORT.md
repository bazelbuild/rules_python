# Bzlmod support

## `rules_python` `bzlmod` support

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

1. Gazelle does not support finding deps in sub-modules.  For instance we can have a dep like ` "@our_other_module//other_module/pkg:lib",` in a `py_test` definition.
2. We have some features that are still not fully flushed out, and the user interface may change.

Check ["issues"](/bazelbuild/rules_python/issues) for an up to date list.

## Differences in behavior from WORKSPACE

### Default toolchain is not the local system Python

Under bzlmod, the default toolchain is no longer based on the locally installed
system Python. Instead, a recent Python version using the pre-built,
standalone runtimes are used.

If you need the local system Python to be your toolchain, then it's suggested
that you setup and configure your own toolchain and register it. Note that using
the local system's Python is not advised because will vary between users and
platforms.

If you want to use the same toolchain as what WORKSPACE used, then manually
register the builtin Bazel Python toolchain by doing
`register_toolchains("@bazel_tools//tools/python:autodetecting_toolchain")`.
**IMPORTANT: this should only be done in a root module, and may intefere with
the toolchains rules_python registers**.

NOTE: Regardless of your toolchain, due to
[#691](https://github.com/bazelbuild/rules_python/issues/691), `rules_python`
still relies on a local Python being available to bootstrap the program before
handing over execution to the toolchain Python.
