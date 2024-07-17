# Getting started

This doc is a simplified guide to help get started started quickly. It provides
a simplified introduction to having a working Python program for both bzlmod
and the older way of using `WORKSPACE`.

It assumes you have a `requirements.txt` file with your PyPI dependencies.

For more details information about configuring `rules_python`, see:
* [Configuring the runtime](toolchains)
* [Configuring third party dependencies (pip/pypi)](pypi-dependencies)
* [API docs](api/index)

## Using bzlmod

The first step to using rules_python with bzlmod is to add the dependency to
your MODULE.bazel file:

```starlark
# Update the version "0.0.0" to the release found here:
# https://github.com/bazelbuild/rules_python/releases.
bazel_dep(name = "rules_python", version = "0.0.0")

pip = use_extension("@rules_python//python/extensions:pip.bzl", "pip")
pip.parse(
    hub_name = "my_deps",
    python_version = "3.11",
    requirements_lock = "//:requirements.txt",
)
use_repo(pip, "my_deps")
```

## Using a WORKSPACE file

Using WORKSPACE is deprecated, but still supported, and a bit more involved than
using Bzlmod. Here is a simplified setup to download the prebuilt runtimes.

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")


# Update the SHA and VERSION to the lastest version available here:
# https://github.com/bazelbuild/rules_python/releases.

SHA="84aec9e21cc56fbc7f1335035a71c850d1b9b5cc6ff497306f84cced9a769841"

VERSION="0.23.1"

http_archive(
    name = "rules_python",
    sha256 = SHA,
    strip_prefix = "rules_python-{}".format(VERSION),
    url = "https://github.com/bazelbuild/rules_python/releases/download/{}/rules_python-{}.tar.gz".format(VERSION,VERSION),
)

load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

load("@rules_python//python:repositories.bzl", "python_register_toolchains")

python_register_toolchains(
    name = "python_3_11",
    # Available versions are listed in @rules_python//python:versions.bzl.
    # We recommend using the same version your team is already standardized on.
    python_version = "3.11",
)

load("@python_3_11//:defs.bzl", "interpreter")

load("@rules_python//python:pip.bzl", "pip_parse")

pip_parse(
    ...
    python_interpreter_target = interpreter,
    ...
)
```

## "Hello World"

Once you've imported the rule set using either Bzlmod or WORKSPACE, you can then
load the core rules in your `BUILD` files with the following:

```starlark
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
  name = "main",
  srcs = ["main.py"],
  deps = [
      "@my_deps//foo",
      "@my_deps//bar",
  ]
)
```
