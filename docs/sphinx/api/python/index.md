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

Deprecated, see {bzl:obj}`@rules_python//python/autodetecting_toolchain:all`.
