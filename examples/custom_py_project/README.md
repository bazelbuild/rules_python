# custom_py_project

This example shows the use of `PyRequirementsInfo`.  Rather than using the
default `py_project` rule, a novel one is implemented here that filters out the
transitive third-party dependencies and gathers up `PyRequirementInfo` which are
included in the `Requires-Dist` wheel metadata.

Notes:

- `//src/lib:lib` is a very simple `py_library` macro that depends on two external
  libs from pypi.
- The `py_library` macro from `//bazel:py_library` declares a `py_wheel` for
  each library rule.
- The `py_package` rule from `//bazel:py_package.bzl` rule processes each file in the default output, ultimately excluding anything that has `/site-packages/` in the path.
  - the `/METADATA` file is used as a representative file from which we parse the
    dependency name and version, creating a corresponding `PyRequirementInfo`.
  - the `PyRequirementInfo` structs are bundled into `PyRequirementsInfo` and returned from the rule.
  - the `PyRequirementsInfo` are picked up by the `py_wheel` rule implementation
    and added to the generated wheel METADATA.
  - the golden test depends on the generated wheel, whose METADATA has been
    extracted and grepped for `Requires-Dist:`.

> NOTE: this example was originally based off `examples/pip_parse_vendored`.
