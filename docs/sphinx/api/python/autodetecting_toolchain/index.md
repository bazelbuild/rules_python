:::{default-domain} bzl
:::
:::{bzl:currentfile} //python/autodetecting_toolchain:BUILD.bazel
:::

# //python/autodetecting_toolchain

::::{target} all

A simple set of toolchains that simply uses `python3` from the runtime environment.

Note that this toolchain provides no build-time information, which makes it of
limited utility.

This is only provided to aid migration off the builtin Bazel toolchain 
(`@bazel_tools//python:autodetecting_toolchain`), and is largely only applicable
to WORKSPACE builds.

:::{deprecated} unspecified

Switch to using a hermetic toolchain or manual toolchain configuration instead.
:::

::::
