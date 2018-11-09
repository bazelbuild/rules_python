---
title: Customizing the Python Stub Template
status: Draft, not yet ready for review
created: 2018-11-08
updated: 2018-11-09
authors:
  - [brandjon@](https://github.com/brandjon)
reviewers:
  - [gpshead@](https://github.com/gpshead)
discussion thread: [bazel #137](https://github.com/bazelbuild/bazel/issues/137)
---

# Customizing the Python Stub Template

## Abstract

This design document proposes a way to use a different Python stub template, so that users can control how the Python interpreter gets invoked to run their targets.

**Open questions:** It is not currently clear whether the use cases warrant this kind of expressivity, or whether users can get by with smaller, more narrowly focused ways of parameterizing the existing stub template. The exact stub API is also to be determined.

## Background

The usual executable artifact of a `py_binary` rule is a Python stub script. This script manipulates the Python environment to set up the module import path and make the runfiles available, before passing control to the underlying user Python program. The stub script is generated from a [stub template](https://github.com/bazelbuild/bazel/blob/ef0024b831a71521390dcb837b24b86485e5998d/src/main/java/com/google/devtools/build/lib/bazel/rules/python/python_stub_template.txt) by [instantiating some placeholders](https://github.com/bazelbuild/bazel/blob/ef0024b831a71521390dcb837b24b86485e5998d/src/main/java/com/google/devtools/build/lib/bazel/rules/python/BazelPythonSemantics.java#L152-L159).

Generally the Python stub and user program is executed using the system Python interpreter of the target platform. Although this is non-hermetic, the details of the interpreter can be reified by a [`py_runtime`](https://docs.bazel.build/versions/master/be/python.html#py_runtime) target. In the future this will allow for platform-aware selection of an appropriate Python interpreter using the [toolchain](https://docs.bazel.build/versions/master/toolchains.html) framework.

## Proposal

A new `Label`-valued attribute, `stub_template`, is added to `py_runtime`. This label points to a file; by default it is `//tools/python:python_stub_template.txt`, which is the renamed location of the existing template. The `py_runtime` rule will resolve this label to an `Artifact` and propagate it in a new field of [`BazelPyRuntimeProvider`](https://github.com/bazelbuild/bazel/blob/1f684e1b87cd8881a0a4b33e86ba66743e32d674/src/main/java/com/google/devtools/build/lib/bazel/rules/python/BazelPyRuntimeProvider.java). [`BazelPythonSemantics#createExecutable`](https://github.com/bazelbuild/bazel/blob/ef0024b831a71521390dcb837b24b86485e5998d/src/main/java/com/google/devtools/build/lib/bazel/rules/python/BazelPythonSemantics.java#L130) will refer to this `Artifact` instead of retrieving the template as a Java resource file.

It is not yet decided which template placeholders are specified, or whether the placeholders will remain an experimental API for the moment.

## Original approach

An earlier proposed approach (suggested on the discussion thread, and implemented by [fahhem@](https://github.com/fahhem)) was to add the `stub_template` attribute to `py_binary` rather than to `py_runtime`.

This would make it trivial to customize the stub for an individual Python target without affecting the other targets in the build. This could be useful if there were a one-off target that had special requirements.

However, the author believes that the stub is more naturally tied to the Python interpreter than to an individual target. Putting the attribute on `py_runtime` makes it easy to affect all Python targets that use the same interpreter. It also allows the same Python target to use different stubs depending on which interpreter it is built for -- for instance, the same target can have different stubs on different platforms.

If it is necessary to use a custom stub for a particular target, that could still be achieved by making that one target use a different `py_runtime`. This isn't possible at the moment but will be when a `py_toolchain` rule is added.

## Changelog

Date         | Change
------------ | ------
2018-11-08   | Initial version
