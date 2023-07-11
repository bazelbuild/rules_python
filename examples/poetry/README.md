# Using Poetry with rules_python

Use Poetry's `poetry.lock` file to declare your rules_python dependencies.

This is a fully hermetic approach which doesn't rely on a system Python interpreter nor any installation of Poetry on your machine.

## Why?

- Your team might simply prefer Poetry for aesthetic reasons.
- Migrating to Bazel is already hard, so you want to continue using your existing Poetry setup. It also allows less disruption for non-Bazel workflows.
- The Poetry lockfile supports multiple platforms, avoiding the awkwardness of the [`requirements_{darwin,linux,windows}.txt`](https://github.com/bazelbuild/rules_python/blob/main/docs/pip.md#compile_pip_requirements-requirements_darwin) triple which is hard to update without having access to all three platforms.

## Approach

We simply treat Poetry as a "frontend" to the existing [`pip_parse`](https://github.com/bazelbuild/rules_python/blob/main/README.md#installing-third_party-packages) repository rule.
Essentially we teach it how to parse an additional format.

Internally, it simply exports the Poetry lockfile within a repository rule, producing a requirements.txt file (for the host platform) which is supported by `pip_parse`.
This is inspired by https://github.com/AndrewGuenther/rules_python_poetry.

Also inspired by https://github.com/jvolkman/rules_pycross/blob/main/update_pypi_requirements_bzl.sh
which had a similar idea of bringing in poetry as a whl_library repository rule so it can be called
under Bazel.

Also inspired by https://docs.aspect.build/rules/aspect_rules_js/docs/pnpm/#update_pnpm_lock which allows JavaScript developers to author one lockfile format (yarn or npm) and translates that on-the-fly to what the Bazel rules expect (pnpm).

See https://github.com/bazelbuild/rules_python/issues/340

## Usage

This folder contains a typical Poetry setup, with direct dependencies and their constraints declared in a `pyproject.toml` file.

You can `bazel run @poetry_poetry//:bin update` to create/update the `poetry.lock` file.
This is typically checked into version control, as shown in this folder.

To illustrate the translation, you can `bazel run @poetry_poetry//:bin export` to write a `requirements.txt` file to stdout. This is what we do internally.

TODO: write a `poetry_export` repository rule around it?
