---
trigger: model_decision
description: rules_python-specific Bzlmod, PyPI, and rule usage invariants
---

# `rules_python` Bzlmod & Rule Invariants

## Unified `@pypi` Hub & `pip.dep()` Declarations (`MODULE.bazel`)
* Declare `pip.dep(name = "<pkg>")` on the non-dev `pip` extension in
  `MODULE.bazel` (with `"pypi"` in `use_repo(pip, "pypi", ...)`) for every
  `@pypi//<pkg>` target referenced by non-test rules, macros, or `BUILD` files
  under `python/**` (directly or via `alias`).
* **Why**: `pip.dep()` registers abstract PyPI package targets in the unified
  `@pypi` hub so downstream Bzlmod consumers do not fail during loading or
  analysis when `<pkg>` is absent from their `pip.parse()` lockfiles. Package
  names in `pip.dep(name = "...")` are normalized (hyphens and underscores map
  to the same name).

## Minimum Supported Bazel Version
* `//:version.bzl` defines `MINIMUM_BAZEL_VERSION`. Do not add compatibility
  logic, feature guards, or comments for older Bazel versions.
* When guarding a feature added after `MINIMUM_BAZEL_VERSION`, verify and
  comment the exact Bazel version that introduced it.
