# Bazel Python Rules

[![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_python)](http://ci.bazel.io/job/rules_python)

## Rules

* [py_library](#py_library)
* [py_binary](#py_binary)

## Overview

This is a placeholder repository that provides aliases for the native Bazel
python rules.  In the future, this will also become the home for rules that
download `pip` packages, and other non-Core Python functionality.

## Setup

Add the following to your `WORKSPACE` file to add the external repositories:

```python
git_repository(
    name = "io_bazel_rules_python",
    remote = "https://github.com/bazelbuild/rules_python.git",
    commit = "{HEAD}",
)
```

Then in your `BUILD` files load the python rules with:

``` python
load(
  "@io_bazel_rules_python//python:python.bzl",
  "py_binary", "py_library"
)

py_binary(
  name = "main",
  ...
)
```

<a name="py_library"></a>
## py_library

See Bazel core [documentation](https://docs.bazel.build/versions/master/be/python.html#py_library).

<a name="py_binary"></a>
## py_binary

See Bazel core [documentation](https://docs.bazel.build/versions/master/be/python.html#py_binary).
