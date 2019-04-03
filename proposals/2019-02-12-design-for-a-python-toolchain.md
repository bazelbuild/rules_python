---
title: Design for a Python Toolchain
status: Accepted
created: 2019-02-12
updated: 2019-02-21
authors:
  - [brandjon@](https://github.com/brandjon)
reviewers:
  - [katre@](https://github.com/katre), [mrovner@](https://github.com/mrovner), [nlopezgi@](https://github.com/nlopezgi)
discussion thread: [bazel #7375](https://github.com/bazelbuild/bazel/issues/7375)
---

# Design for a Python Toolchain

## Abstract

This doc outlines the design of a Python toolchain rule and its associated machinery. Essentially a new `py_runtime_pair` toolchain rule is created to wrap two `py_runtime` targets (one for Python 2 and one for Python 3), thereby making runtimes discoverable via [toolchain resolution](https://docs.bazel.build/versions/master/toolchains.html). This replaces the previous mechanism of explicitly specifying a global runtime via `--python_top` or `--python_path`; those flags are now deprecated.

The new toolchain-related definitions are implemented in Starlark. A byproduct of this is that the provider type for `py_runtime` is exposed to Starlark. We also add to `py_runtime` an attribute for declaring whether it represents a Python 2 or Python 3 runtime.

## Motivation

The goal is to make the native Python rules use the toolchain framework to resolve the Python runtime. Advantages include:

* allowing each `py_binary` to use a runtime suitable for its target platform

* allowing Python 2 and Python 3 targets to run in the same build without [hacks](https://github.com/bazelbuild/bazel/issues/4815#issuecomment-460777113)

* making it easier to run Python-related builds under remote execution

* adding support for autodetection of available system Python runtimes, without requiring ad hoc rule logic

* removing `--python_top` and `--python_path`

* bringing Python in line with other rule sets and Bazel's best practices

**Non-goal:** This work does not allow individual `py_binary`s to directly name a Python runtime to use. Instead, this information should be worked into either the configuration or a future toolchain constraint system. See the FAQ, below.

## Design

### New definitions

A new [toolchain type](https://docs.bazel.build/versions/master/toolchains.html#writing-rules-that-use-toolchains) is created at `@bazel_tools//tools/python:toolchain_type`. This is the type for toolchains that provide a way to run Python code.

Toolchain rules of this type are expected to return a [`ToolchainInfo`](https://docs.bazel.build/versions/master/skylark/lib/ToolchainInfo.html) with two fields, `py2_runtime` and `py3_runtime`, each of type `PyRuntimeInfo`. They are used for `PY2` and `PY3` binaries respectively.

```python
def _some_python_toolchain_impl(ctx):
    ...
    return [platform_common.ToolchainInfo(
        py2_runtime = PyRuntimeInfo(...),
        py3_runtime = PyRuntimeInfo(...))]
```

If either Python 2 or Python 3 is not provided by the toolchain, the corresponding field may be set to `None`. This is strongly discouraged, as it will prevent any target relying on that toolchain from using that version of Python. Toolchains that do use `None` here should be registered with lower priority than other toolchains, so that they are chosen only as a fallback.

`PyRuntimeInfo` is the newly-exposed Starlark name of the native provider returned by the [`py_runtime`](https://docs.bazel.build/versions/master/be/python.html#py_runtime) rule. Like `PyInfo`, it is a top-level built-in name. Also like `PyInfo` and the native Python rules, it will eventually be migrated to Starlark and moved out of the Bazel repository.

A `PyRuntimeInfo` describes either a *platform runtime* or an *in-build runtime*. A platform runtime accesses a system-installed interpreter at a known path, whereas an in-build runtime points to a build target that acts as the interpreter. In both cases, an "interpreter" is really any executable binary or wrapper script that is capable of running a Python script passed on the command line, following the same conventions as the standard CPython interpreter. Note that any platform runtime imposes a requirement on the target platform. Therefore, any toolchain returning such a `PyRuntimeInfo` should include a corresponding target platform constraint, to ensure it cannot be selected for a platform that does not have the interpreter at that path. Even an in-build runtime can require platform constraints, for instance in the case of a wrapper script that invokes the system interpreter.

We provide two [`constraint_setting`](https://docs.bazel.build/versions/master/be/platform.html#constraint_setting)s to act as a standardized namespace for this kind of platform constraint: `@bazel_tools//tools/python:py2_interpreter_path` and `@bazel_tools//tools/python:py3_interpreter_path`. This doc does not mandate any particular structure for the names of [`constraint_value`](https://docs.bazel.build/versions/master/be/platform.html#constraint_value)s associated with these settings. If a platform does not provide a Python 2 runtime, it should have no constraint value associated with `py2_interpreter_path`, and similarly for Python 3.

`PyRuntimeInfo` has the following fields, each of which corresponds to an attribute on `py_runtime`. (The last one, `python_version`, is newly added in this doc.)

* `interpreter_path`: If this is a platform runtime, this field is the absolute filesystem path to the interpreter on the target platform. Otherwise, this is `None`.

* `interpreter`: If this is an in-build runtime, this field is a `File` representing the interpreter. Otherwise, this is `None`.

* `files`: If this is an in-build runtime, this field is a depset of `File`s that need to be added to the runfiles of an executable target that uses this toolchain. The value of `interpreter` need not be included in this field. If this is a platform runtime then this field is `None`.

* `python_version`: Either the string `"PY2"` or `"PY3"`, indicating which version of Python the interpreter referenced by `interpreter_path` or `interpreter` is.

The constructor of `PyRuntimeInfo` takes each of these fields as keyword arguments. The constructor enforces the invariants about which combinations of fields may be `None`. Fields that are not meaningful may be omitted; e.g. when `interpreter_path` is given, `interpreter` and `files` may be omitted instead of passing `None`.

It is not possible to directly specify a system command (e.g. `"python"`) in `interpreter_path`. However, this can be done indirectly by creating a wrapper script that invokes the system command, and referencing that script from the `interpreter` field.

Finally, we define a standard Python toolchain rule implementing the new toolchain type. The rule's name is `py_runtime_pair` and it can be loaded from `@bazel_tools//tools/python:toolchain.bzl`. It has two label-valued attributes, `py2_runtime` and `py3_runtime`, that refer to `py_runtime` targets.

### Changes to the native Python rules

The executable Python rules [`py_binary`](https://docs.bazel.build/versions/master/be/python.html#py_binary) and [`py_test`](https://docs.bazel.build/versions/master/be/python.html#py_test) are modified to require the new toolchain type. The Python runtime information is obtained by retrieving a `PyRuntimeInfo` from either the `py2_runtime` or `py3_runtime` field of the toolchain, rather than from `--python_top`. The `python_version` field of the `PyRuntimeInfo` is also checked to ensure that a `py_runtime` didn't accidentally end up in the wrong place.

Since `--python_top` is no longer read, it is deprecated. Since `--python_path` was only read when no runtime information is available, but the toolchain must always be present, it too is deprecated.

Implementation wise, the native `PyRuntimeProvider` is turned into the user-visible `PyRuntimeInfo` by adding Starlark API annotations in the usual way (`@SkylarkCallable`, etc.). A previous version of this proposal suggested defining `PyRuntimeInfo` in Starlark underneath `@bazel_tools` and accessing it from the native rules, but this is technically difficult to implement.

A `python_version` attribute is added to `py_runtime`. It is mandatory and accepts values `"PY2"` and `"PY3"` only.

As a drive-by cleanup (and non-breaking change), the `files` attribute of `py_runtime` is made optional. For the non-hermetic case, specifying `files` is nonsensical and it is even an error to give it a non-empty value. For the hermetic case, `files` can be useful but is by no means necessary if the interpreter requires no additional in-repo inputs (such as when the "interpreter" is just a wrapper script that dispatches to the platform's system interpreter).

### Default toolchain

For convenience, we supply a predefined [toolchain](https://docs.bazel.build/versions/master/be/platform.html#toolchain) of last resort, `@bazel_tools//tools/python:autodetecting_python_toolchain`. This toolchain is registered with lower priority than any user-registered Python toolchain. It simply dispatches to a wrapper script that tries to locate a suitable interpreter from `PATH` at runtime, on a best-effort basis. It has no platform constraints.

## Example

Here is a minimal example that defines a platform whose Python interpreters are located under a non-standard path. The example also defines a Python toolchain to accompany this platform.

```python
# //platform_defs:BUILD

load("@bazel_tools//tools/python:toolchain.bzl", "py_runtime_pair")

# Constraint values that represent that the system's "python2" and "python3"
# executables are located under /usr/weirdpath.

constraint_value(
    name = "usr_weirdpath_python2",
    constraint_setting = "@bazel_tools//tools/python:py2_interpreter_path",
)

constraint_value(
    name = "usr_weirdpath_python3",
    constraint_setting = "@bazel_tools//tools/python:py3_interpreter_path",
)

# A definition of a platform whose Python interpreters are under these paths.

platform(
    name = "my_platform",
    constraint_values = [
        ":usr_weirdpath_python2",
        ":usr_weirdpath_python3",
    ],
)

# Python runtime definitions that reify these system paths as BUILD targets.

py_runtime(
    name = "my_platform_py2_runtime",
    interpreter_path = "/usr/weirdpath/python2",
)

py_runtime(
    name = "my_platform_py3_runtime",
    interpreter_path = "/usr/weirdpath/python3",
)

py_runtime_pair(
    name = "my_platform_runtimes",
    py2_runtime = ":my_platform_py2_runtime",
    py3_runtime = ":my_platform_py3_runtime",
)

# A toolchain definition to expose these runtimes to toolchain resolution.

toolchain(
    name = "my_platform_python_toolchain",
    # Since the Python interpreter is invoked at runtime on the target
    # platform, there's no need to specify execution platform constraints here.
    target_compatible_with = [
        # Make sure this toolchain is only selected for a target platform that
        # advertises that it has interpreters available under /usr/weirdpath.
        ":usr_weirdpath_python2",
        ":usr_weirdpath_python3",
    ],
    toolchain = ":my_platform_runtimes",
    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
)
```

```python
# //pkg:BUILD

# An ordinary Python target to build.
py_binary(
    name = "my_pybin",
    srcs = ["my_pybin.py"],
    python_version = "PY3",
)
```

```python
# WORKSPACE

# Register the custom Python toolchain so it can be chosen for my_platform.
register_toolchains(
    "//platform_defs:my_platform_python_toolchain",
)
```

We can then build with

```
bazel build //pkg:my_pybin --platforms=//platform_defs:my_platform
```

and thanks to toolchain resolution, the resulting executable will automatically know to use the interpreter located at `/usr/weirdpath/python3`.

If we had not defined a custom toolchain, then we'd be stuck with `autodetecting_python_toolchain`, which would fail at execution time if `/usr/weirdpath` were not on `PATH`. (It would also be slightly slower since it requires an extra invocation of the interpreter at execution time to confirm its version.)

## Backward compatibility

The new `@bazel_tools` definitions and the `PyRuntimeInfo` provider are made available immediately. A new flag, `--incompatible_use_python_toolchains`, is created to assist migration. When the flag is enabled, `py_binary` and `py_test` will use the `PyRuntimeInfo` obtained from the toolchain, instead of the one obtained from `--python_top` or the default information in `--python_path`. In addition, when `--incompatible_use_python_toolchains` is enabled it is an error to set the following flags: `--python_top`, `--python_path`, `--python2_path`, `--python3_path`. (The latter two were already deprecated.) These flags will be deleted when the incompatible flag is removed.

Because of how the toolchain framework is implemented, it is not possible to gate whether a rule requires a toolchain type based on a flag. Therefore `py_binary` and `py_test` are made to require `@bazel_tools//tools/python:toolchain_type` immediately and unconditionally. This may impact how toolchain resolution determines the toolchains and execution platforms for a given build, but should not otherwise cause problems so long as the build uses constraints correctly.

The new `python_version` attribute is added to `py_runtime` immediately. Its default value is the same as the `python_version` attribute for `py_binary`, i.e. `PY3` if `--incompatible_py3_is_default` is true and `PY2` otherwise. When `--incompatible_use_python_toolchains` is enabled this attribute becomes mandatory.

## FAQ

#### How can I force a `py_binary` to use a given runtime, say for a particular minor version of Python?

This is not directly addressed by this doc. Note that such a system could be used not just for controlling the minor version of the interpreter, but also to choose between different Python implementations (CPython vs PyPy), compilation modes (optimized, debug), an interpreter linked with a pre-selected set of extensions, etc.

There are two possible designs.

The first design is to put this information in the configuration, and have the toolchain read the configuration to decide which `PyRuntimeInfo` to return. We'd use Starlark Build Configurations to define a flag to represent the Python minor version, and transition the `py_binary` target's configuration to use this version. This configuration would be inherited by the resolved toolchain just like any other dependency inherits its parents configuration. The toolchain could then use a `select()` on the minor version flag to choose which `py_runtime` to depend on.

There's one problem: Currently all toolchains are analyzed in the host configuration. It is expected that this will be addressed soon.

We could even migrate the Python major version to use this approach. Instead of having two different `ToolchainInfo` fields, `py2_runtime` and `py3_runtime`, we'd have a single `py_runtime` field that would be populated with one or the other based on the configuration. (It's still a good idea to keep them as separate attributes in the user-facing toolchain rule, i.e. `py_runtime_pair`, because it's a very common use case to require both major versions of Python in a build. But note that this causes both runtimes to be analyzed as dependencies, even if the whole build uses only one or the other.)

The second design for controlling what runtime is chosen is to introduce additional constraints on the toolchain, and let toolchain resolution solve the problem. However, currently toolchains only support constraints on the target and execution platforms, and this is not a platform-related constraint. What would be needed is a per-target semantic-level constraint system.

The second approach has the advantage of allowing individual runtimes to be registered independently, without having to combine them into a massive `select()`. But the first approach is much more feasible to implement in the short-term.

#### Why `py_runtime_pair` as opposed to some other way of organizing multiple Python runtimes?

Alternatives might include a dictionary mapping from version identifiers to runtimes, or a list of runtimes paired with additional metadata.

The `PY2`/`PY3` dichotomy is already baked into the Python rule set and indeed the Python ecosystem at large. Keeping this concept in the toolchain rule serves to complement, rather than complicate, Bazel's existing Python support.

It will always be possible to add new toolchains, first by extending the schema of the `ToolchainInfo` accepted by the Python rules, and then by defining new user-facing toolchain rules that serve as front-ends for this provider.

#### Why not split Python 2 and Python 3 into two separate toolchain types?

The general pattern for rule sets seems to be to have a single toolchain type representing all of a language's concerns. Case in point: The naming convention for toolchain types is to literally name the target "toolchain_type", and let the package path distinguish its label.

If the way of categorizing Python runtimes changes in the future, it will probably be easier to migrate rules to use a new provider schema than to use a new set of toolchain types.

#### How does the introduction of new symbols to `@bazel_tools` affect the eventual plan to migrate the Python rules to `bazelbuild/rules_python`?

The new `PyRuntimeInfo` provider and `py_runtime_pair` rule would have forwarding aliases set up, so they could be accessed both from `@bazel_tools` and `rules_python` during a future migration window.

Forwarding aliases would also be defined for the toolchain type and the two `constraint_setting`s. Note that aliasing `toolchain_type`s is currently broken ([#7404](https://github.com/bazelbuild/bazel/issues/7404)).

In the initial implementation of this proposal, the predefined `autodetecting_python_toolchain` will be automatically registered in the user's workspace by Bazel. This follows precedent for other languages with built-in support in Bazel. Once the rules are migrated to `rules_python`, registration will not be automatic; the user will have to explicitly call a configuration helper defined in `rules_python` from their own `WORKSPACE` file.

## Changelog

Date         | Change
------------ | ------
2019-02-12   | Initial version
2019-02-14   | Make `PyRuntimeInfo` natively defined
2019-02-15   | Clarify platform runtime vs in-build runtime
2019-02-21   | Formal approval
