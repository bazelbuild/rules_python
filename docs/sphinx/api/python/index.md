:::{default-domain} bzl
:::
:::{bzl:currentfile} //python:BUILD.bazel
:::

# //python

:::{bzl:target} toolchain_type

Identifier for the toolchain type for the target platform.
:::

:::{bzl:target} exec_tools_toolchain_type

Identifier for the toolchain type for exec tools used to build Python targets.
:::

:::{bzl:target} current_py_toolchain

Helper target to resolve to the consumer's current Python toolchain. This target
provides:

* `PyRuntimeInfo`: The consuming target's target toolchain information

:::

::::{target} autodetecting_toolchain

A simple toolchain that simply uses `python3` from the runtime environment.

Note that this toolchain provides no build-time information, which makes it of
limited utility.

This is only provided to aid migration off the builtin Bazel toolchain 
(`@bazel_tools//python:autodetecting_toolchain`), and is largely only applicable
to WORKSPACE builds.

:::{deprecated} unspecified

Switch to using a hermetic toolchain or manual toolchain configuration instead.
:::

::::
