# rules_python Changelog

This is a human-friendly changelog in a keepachangelog.com style format.
Because this changelog is for end-user consumption of meaningful changes,only
a summary of a release's changes is described. This means every commit is not
necessarily mentioned, and internal refactors or code cleanups are omitted
unless they're particularly notable.

A brief description of the categories of changes:

* `Changed`: Some behavior changed. If the change is expected to break a
  public API or supported behavior, it will be marked as **BREAKING**. Note that
  beta APIs will not have breaking API changes called out.
* `Fixed`: A bug, or otherwise incorrect behavior, was fixed.
* `Added`: A new feature, API, or behavior was added in a backwards compatible
  manner.
* Particular sub-systems are identified using parentheses, e.g. `(bzlmod)` or
  `(docs)`.

## Unreleased

### Changed

* Python version patch level bumps:
  * 3.8.15  -> 3.8.18
  * 3.9.17  -> 3.9.18
  * 3.10.12 -> 3.10.13
  * 3.11.4  -> 3.11.6

* (deps) Upgrade rules_go 0.39.1 -> 0.41.0; this is so gazelle integration works with upcoming Bazel versions

* (multi-version) The `distribs` attribute is no longer propagated. This
  attribute has been long deprecated by Bazel and shouldn't be used.

* Calling `//python:repositories.bzl#py_repositories()` is required. It has
  always been documented as necessary, but it was possible to omit it in certain
  cases. An error about `@rules_python_internal` means the `py_repositories()`
  call is missing in `WORKSPACE`.

* (bzlmod) The `pip.parse` extension will generate os/arch specific lock
  file entries on `bazel>=6.4`.


### Added

* (bzlmod, entry_point) Added
  [`py_console_script_binary`](./docs/py_console_script_binary.md), which
  allows adding custom dependencies to a package's entry points and customizing
  the `py_binary` rule used to build it.

* New Python versions available: `3.8.17`, `3.11.5` using
  https://github.com/indygreg/python-build-standalone/releases/tag/20230826.

* (gazelle) New `# gazelle:python_generation_mode file` directive to support
  generating one `py_library` per file.

* (python_repository) Support `netrc` and `auth_patterns` attributes to enable
  authentication against private HTTP hosts serving Python toolchain binaries.

* `//python:packaging_bzl` added, a `bzl_library` for the Starlark
  files `//python:packaging.bzl` requires.
* (py_wheel) Added the `incompatible_normalize_name` feature flag to
  normalize the package distribution name according to latest Python
  packaging standards. Defaults to `False` for the time being.
* (py_wheel) Added the `incompatible_normalize_version` feature flag
  to normalize the package version according to PEP440 standard. This
  also adds support for local version specifiers (versions with a `+`
  in them), in accordance with PEP440. Defaults to `False` for the
  time being.

* New Python versions available: `3.8.18`, `3.9.18`, `3.10.13`, `3.11.6`, `3.12.0` using
  https://github.com/indygreg/python-build-standalone/releases/tag/20231002.
  `3.12.0` support is considered beta and may have issues.

### Removed

* (bzlmod) The `entry_point` macro is no longer supported and has been removed
  in favour of the `py_console_script_binary` macro for `bzlmod` users.

* (bzlmod) The `pip.parse` no longer generates `{hub_name}_{py_version}` hub repos
  as the `entry_point` macro has been superseded by `py_console_script_binary`.

* (bzlmod) The `pip.parse` no longer generates `{hub_name}_{distribution}` hub repos.

### Fixed

* (whl_library) No longer restarts repository rule when fetching external
  dependencies improving initial build times involving external dependency
  fetching.

* (gazelle) Improve runfiles lookup hermeticity.

## [0.25.0] - 2023-08-22

### Changed

* Python version patch level bumps:
  * 3.9.16 -> 3.9.17
  * 3.10.9 -> 3.10.12
  * 3.11.1 -> 3.11.4
* (bzlmod) `pip.parse` can no longer automatically use the default
  Python version; this was an unreliable and unsafe behavior. The
  `python_version` arg must always be explicitly specified.

### Fixed

* (docs) Update docs to use correct bzlmod APIs and clarify how and when to use
  various APIs.
* (multi-version) The `main` arg is now correctly computed and usually optional.
* (bzlmod) `pip.parse` no longer requires a call for whatever the configured
  default Python version is.

### Added

* Created a changelog.
* (gazelle) Stop generating unnecessary imports.
* (toolchains) s390x supported for Python 3.9.17, 3.10.12, and 3.11.4.

[0.25.0]: https://github.com/bazelbuild/rules_python/releases/tag/0.25.0

## [0.24.0] - 2023-07-11

### Changed

* **BREAKING** (gazelle) Gazelle 0.30.0 or higher is required
* (bzlmod) `@python_aliases` renamed to `@python_versions
* (bzlmod) `pip.parse` arg `name` renamed to `hub_name`
* (bzlmod) `pip.parse` arg `incompatible_generate_aliases` removed and always
  true.

### Fixed

* (bzlmod) Fixing Windows Python Interpreter symlink issues
* (py_wheel) Allow twine tags and args
* (toolchain, bzlmod) Restrict coverage tool visibility under bzlmod
* (pip) Ignore temporary pyc.NNN files in wheels
* (pip) Add format() calls to glob_exclude templates
* plugin_output in py_proto_library rule

### Added

* Using Gazelle's lifecycle manager to manage external processes
* (bzlmod) `pip.parse` can be called multiple times with different Python
  versions
* (bzlmod) Allow bzlmod `pip.parse` to reference the default python toolchain and interpreter
* (bzlmod) Implementing wheel annotations via `whl_mods`
* (gazelle) support multiple requirements files in manifest generation
* (py_wheel) Support for specifying `Description-Content-Type` and `Summary` in METADATA
* (py_wheel) Support for specifying `Project-URL`
* (compile_pip_requirements) Added `generate_hashes` arg (default True) to
  control generating hashes
* (pip) Create all_data_requirements alias
* Expose Python C headers through the toolchain.

[0.24.0]: https://github.com/bazelbuild/rules_python/releases/tag/0.24.0
