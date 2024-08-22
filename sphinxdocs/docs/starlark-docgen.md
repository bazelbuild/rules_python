# Starlark docgen

Using the `sphinx_stardoc` rule, API documentation can be generated from bzl
source code. This rule requires both MyST-based markdown and the `sphinx_bzl`
Sphinx extension are enabled. This allows source code to use Markdown and
Sphinx syntax to create rich documentation with cross references, types, and
more.


## Configuring Sphinx

While the `sphinx_stardoc` rule doesn't require Sphinx itself, the source
it generates requires some additional Sphinx plugins and config settings.

When defining the `sphinx_build_binary` target, also depend on:
* `@rules_python//sphinxdocs/src/sphinx_bzl:sphinx_bzl`
* `myst_parser` (e.g. `@pypi//myst_parser`)
* `typing_extensions` (e.g. `@pypi//myst_parser`)

```
sphinx_build_binary(
    name = "sphinx-build",
    deps = [
        "@rules_python//sphinxdocs/src/sphinx_bzl",
        "@pypi//myst_parser",
        "@pypi//typing_extensions",
        ...
    ]
)
```

In `conf.py`, enable the `sphinx_bzl` extension, `myst_parser` extension,
and the `colon_fence` MyST extension.

```
extensions = [
    "myst_parser",
    "sphinx_bzl.bzl",
]

myst_enable_extensions = [
    "colon_fence",
]
```

## Generating docs from bzl files

To convert the bzl code to Sphinx doc sources, `sphinx_stardocs` is the primary
rule to do so. It takes a list of `bzl_library` targets or files and generates docs for
each. When a `bzl_library` target is passed, the `bzl_library.srcs` value can only
have a single file.

Example:

```
sphinx_stardocs(
    name = "my_docs",
    srcs = [
      ":binary_bzl",
      ":library_bzl",
    ]
)

bzl_library(
   name = "binary_bzl",
   srcs = ["binary.bzl"],
   deps = ...
)

bzl_library(
   name = "library_bzl",
   srcs = ["library.bzl"],
   deps = ...
)
```
