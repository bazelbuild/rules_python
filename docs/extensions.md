<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Module extensions for use with bzlmod.

## pip_parse

You can use the `pip_parse` to access the generate entry_point targets as follows.
First, ensure you use the `incompatible_generate_aliases=True` feature to re-export the
external spoke repository contents in distinct folders in the hub repo:
```starlark
pip = use_extension("@rules_python//python:extensions.bzl", "pip")
pip.parse(
    name = "pypi",
    # Generate aliases for more ergonomic consumption of dependencies from
    # the `pypi` external repo.
    incompatible_generate_aliases = True,
    requirements_lock = "//:requirements_lock.txt",
    requirements_windows = "//:requirements_windows.txt",
)
use_repo(pip, "pip")
```

Then, similarly to the legacy usage, you can create an alias for the `flake8` entry_point:
```starlark
load("@pypi//flake8:bin.bzl", "bin")

alias(
    name = "flake8",
    actual = bin.flake8,
)
```

