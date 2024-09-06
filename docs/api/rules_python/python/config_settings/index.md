:::{default-domain} bzl
:::
:::{bzl:currentfile} //python/config_settings:BUILD.bazel
:::

# //python/config_settings

:::{bzl:flag} python_version
Determines the default hermetic Python toolchain version. This can be set to
one of the values that `rules_python` maintains.
:::

::::{bzl:flag} exec_tools_toolchain
Determines if the {obj}`exec_tools_toolchain_type` toolchain is enabled.

:::{note}
* Note that this only affects the rules_python generated toolchains.
:::

Values:

* `enabled`: Allow matching of the registered toolchains at build time.
* `disabled`: Prevent the toolchain from being matched at build time.

:::{versionadded} 0.33.2
:::
::::

::::{bzl:flag} precompile
Determines if Python source files should be compiled at build time.

:::{note}
The flag value is overridden by the target level {attr}`precompile` attribute,
except for the case of `force_enabled` and `forced_disabled`.
:::

Values:

* `auto`: (default) Automatically decide the effective value based on environment,
  target platform, etc.
* `enabled`: Compile Python source files at build time. Note that
  {bzl:obj}`--precompile_add_to_runfiles` affects how the compiled files are included into
  a downstream binary.
* `disabled`: Don't compile Python source files at build time.
* `if_generated_source`: Compile Python source files, but only if they're a
  generated file.
* `force_enabled`: Like `enabled`, except overrides target-level setting. This
  is mostly useful for development, testing enabling precompilation more
  broadly, or as an escape hatch if build-time compiling is not available.
* `force_disabled`: Like `disabled`, except overrides target-level setting. This
  is useful useful for development, testing enabling precompilation more
  broadly, or as an escape hatch if build-time compiling is not available.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} precompile_source_retention
Determines, when a source file is compiled, if the source file is kept
in the resulting output or not.

:::{note}
This flag is overridden by the target level `precompile_source_retention`
attribute.
:::

Values:

* `auto`: (default) Automatically decide the effective value based on environment,
  target platform, etc.
* `keep_source`: Include the original Python source.
* `omit_source`: Don't include the orignal py source.
* `omit_if_generated_source`: Keep the original source if it's a regular source
  file, but omit it if it's a generated file.

:::{versionadded} 0.33.0
:::
:::{versionadded} 0.36.0
The `auto` value
:::
::::

::::{bzl:flag} precompile_add_to_runfiles
Determines if a target adds its compiled files to its runfiles.

When a target compiles its files, but doesn't add them to its own runfiles, it
relies on a downstream target to retrieve them from
{bzl:obj}`PyInfo.transitive_pyc_files`

Values:
* `always`: Always include the compiled files in the target's runfiles.
* `decided_elsewhere`: Don't include the compiled files in the target's
  runfiles; they are still added to {bzl:obj}`PyInfo.transitive_pyc_files`. See
  also: {bzl:obj}`py_binary.pyc_collection` attribute. This is useful for allowing
  incrementally enabling precompilation on a per-binary basis.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} pyc_collection
Determine if `py_binary` collects transitive pyc files.

:::{note}
This flag is overridden by the target level `pyc_collection` attribute.
:::

Values:
* `include_pyc`: Include `PyInfo.transitive_pyc_files` as part of the binary.
* `disabled`: Don't include `PyInfo.transitive_pyc_files` as part of the binary.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} py_linux_libc
Set what libc is used for the target platform. This will affect which whl binaries will be pulled and what toolchain will be auto-detected. Currently `rules_python` only supplies toolchains compatible with `glibc`.

Values:
* `glibc`: Use `glibc`, default.
* `muslc`: Use `muslc`.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} pip_whl
Set what distributions are used in the `pip` integration.

Values:
* `auto`: Prefer `whl` distributions if they are compatible with a target
  platform, but fallback to `sdist`. This is the default.
* `only`: Only use `whl` distributions and error out if it is not available.
* `no`: Only use `sdist` distributions. The wheels will be built non-hermetically in the `whl_library` repository rule.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} pip_whl_osx_arch
Set what wheel types we should prefer when building on the OSX platform.

Values:
* `arch`: Prefer architecture specific wheels.
* `universal`: Prefer universal wheels that usually are bigger and contain binaries for both, Intel and ARM architectures in the same wheel.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} pip_whl_glibc_version
Set the minimum `glibc` version that the `py_binary` using `whl` distributions from a PyPI index should support.

Values:
* `""`: Select the lowest available version of each wheel giving you the maximum compatibility. This is the default.
* `X.Y`: The string representation of a `glibc` version. The allowed values depend on the `requirements.txt` lock file contents.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} pip_whl_muslc_version
Set the minimum `muslc` version that the `py_binary` using `whl` distributions from a PyPI index should support.

Values:
* `""`: Select the lowest available version of each wheel giving you the maximum compatibility. This is the default.
* `X.Y`: The string representation of a `muslc` version. The allowed values depend on the `requirements.txt` lock file contents.
:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} pip_whl_osx_version
Set the minimum `osx` version that the `py_binary` using `whl` distributions from a PyPI index should support.

Values:
* `""`: Select the lowest available version of each wheel giving you the maximum compatibility. This is the default.
* `X.Y`: The string representation of the MacOS version. The allowed values depend on the `requirements.txt` lock file contents.

:::{versionadded} 0.33.0
:::
::::

::::{bzl:flag} bootstrap_impl
Determine how programs implement their startup process.

Values:
* `system_python`: Use a bootstrap that requires a system Python available
  in order to start programs. This requires
  {obj}`PyRuntimeInfo.bootstrap_template` to be a Python program.
* `script`: Use a bootstrap that uses an arbitrary executable script (usually a
  shell script) instead of requiring it be a Python program.

:::{note}
The `script` bootstrap requires the toolchain to provide the `PyRuntimeInfo`
provider from `rules_python`. This loosely translates to using Bazel 7+ with a
toolchain created by rules_python. Most notably, WORKSPACE builds default to
using a legacy toolchain built into Bazel itself which doesn't support the
script bootstrap. If not available, the `system_python` bootstrap will be used
instead.
:::

:::{seealso}
{obj}`PyRuntimeInfo.bootstrap_template` and
{obj}`PyRuntimeInfo.stage2_bootstrap_template`
:::

:::{versionadded} 0.33.0
:::

::::
