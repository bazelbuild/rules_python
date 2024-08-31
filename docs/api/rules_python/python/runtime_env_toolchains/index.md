:::{default-domain} bzl
:::
:::{bzl:currentfile} //python/runtime_env_toolchains:BUILD.bazel
:::

# //python/runtime_env_toolchains

::::{target} all

A set of toolchains that invoke `python3` from the runtime environment.

Note that this toolchain provides no build-time information, which makes it of
limited utility. This is because the invocation of `python3` is done when a
program is run, not at build time.

This is only provided to aid migration off the builtin Bazel toolchain 
(`@bazel_tools//python:autodetecting_toolchain`), and is largely only applicable
to WORKSPACE builds.

To use this target, register it as a toolchain in WORKSPACE or MODULE.bazel:

:::
register_toolchains("@rules_python//python/runtime_env_toolchains:all")
:::

The benefit of this target over the legacy targets is this defines additional
toolchain types that rules_python needs. This prevents toolchain resolution from
continuing to search elsewhere (e.g. potentially incurring a download of the
hermetic runtimes when they won't be used).

:::{deprecated} 0.34.0

Switch to using a hermetic toolchain or manual toolchain configuration instead.
:::

:::{versionadded} 0.34.0
:::
::::
