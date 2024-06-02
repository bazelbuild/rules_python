:::{default-domain} bzl
:::
:::{bzl:currentfile} //python/config_settings:BUILD.bazel
:::

# //python/config_settings

:::{bzl:flag} precompile
Determines if Python source files should be compiled at build time.

NOTE: The flag value is overridden by the target level `precompile` attribute,
except for the case of `force_enabled` and `forced_disabled`.

Values:

* `auto`: Automatically decide the effective value based on environment,
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
:::

:::{bzl:flag} precompile_source_retention
Determines, when a source file is compiled, if the source file is kept
in the resulting output or not.

NOTE: This flag is overridden by the target level `precompile_source_retention`
attribute.

Values:

* `keep_source`: Include the original Python source.
* `omit_source`: Don't include the orignal py source.
* `omit_if_generated_source`: Keep the original source if it's a regular source
  file, but omit it if it's a generated file.
:::

:::{bzl:flag} precompile_add_to_runfiles
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
:::

:::{bzl:flag} pyc_collection
Determine if `py_binary` collects transitive pyc files.

NOTE: This flag is overridden by the target level `pyc_collection` attribute.

Values:
* `include_pyc`: Include `PyInfo.transitive_pyc_files` as part of the binary.
* `disabled`: Don't include `PyInfo.transitive_pyc_files` as part of the binary.
:::

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
