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

## [0.25.0] - 2023-08-22

### Changed

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


