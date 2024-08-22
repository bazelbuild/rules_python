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

Legacy toolchain; despite its name, it doesn't autodetect anything.

:::{deprecated} 0.34.0

Use {obj}`@rules_python//python/runtime_env_toolchain:all` instead.
:::
::::

