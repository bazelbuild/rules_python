# pip_parse vendored

This example is like pip_parse, however we avoid loading from the generated file.
See https://github.com/bazelbuild/rules_python/issues/608
and https://blog.aspect.dev/avoid-eager-fetches.

The requirements now form a triple:

- requirements.in - human editable, expresses only direct dependencies and load-bearing version constraints
- requirements.txt - lockfile produced by pip-compile or other means
- requirements.bzl - the "parsed" version of the lockfile readable by Bazel downloader
