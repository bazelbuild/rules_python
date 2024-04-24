(pip-integration)=
# Pip Integration

To pull in dependencies from PyPI, the `pip_parse` function is used, which
invokes `pip` to download and install dependencies from PyPI.

In your WORKSPACE file:

```starlark
load("@rules_python//python:pip.bzl", "pip_parse")

pip_parse(
    name = "pip_deps",
    requirements_lock = ":requirements.txt",
)

load("@pip_deps//:requirements.bzl", "install_deps")

install_deps()
```

You can then reference installed dependencies from a `BUILD` file with:

```starlark
load("@pip_deps//:requirements.bzl", "requirement")

py_library(
    name = "bar",
    ...
    deps = [
        "//my/other:dep",
        requirement("requests"),
        requirement("numpy"),
    ],
)
```

In addition to the `requirement` macro, which is used to access the generated `py_library`
target generated from a package's wheel, The generated `requirements.bzl` file contains
functionality for exposing [entry points][whl_ep] as `py_binary` targets as well.

[whl_ep]: https://packaging.python.org/specifications/entry-points/

```starlark
load("@pip_deps//:requirements.bzl", "entry_point")

alias(
    name = "pip-compile",
    actual = entry_point(
        pkg = "pip-tools",
        script = "pip-compile",
    ),
)
```

Note that for packages whose name and script are the same, only the name of the package
is needed when calling the `entry_point` macro.

```starlark
load("@pip_deps//:requirements.bzl", "entry_point")

alias(
    name = "flake8",
    actual = entry_point("flake8"),
)
```

(vendoring-requirements)=
## Vendoring the requirements.bzl file

In some cases you may not want to generate the requirements.bzl file as a repository rule
while Bazel is fetching dependencies. For example, if you produce a reusable Bazel module
such as a ruleset, you may want to include the requirements.bzl file rather than make your users
install the WORKSPACE setup to generate it.
See https://github.com/bazelbuild/rules_python/issues/608

This is the same workflow as Gazelle, which creates `go_repository` rules with
[`update-repos`](https://github.com/bazelbuild/bazel-gazelle#update-repos)

To do this, use the "write to source file" pattern documented in
https://blog.aspect.dev/bazel-can-write-to-the-source-folder
to put a copy of the generated requirements.bzl into your project.
Then load the requirements.bzl file directly rather than from the generated repository.
See the example in rules_python/examples/pip_parse_vendored.


(credential-helper)=
## Credential Helper

The "use Bazel downloader for python wheels" experimental feature includes support for the Bazel
[Credential Helper][cred-helper-design].

Your python artifact registry may provide a credential helper for you. Refer to your index's docs
to see if one is provided.

See the [Credential Helper Spec][cred-helper-spec] for details.

[cred-helper-design]: https://github.com/bazelbuild/proposals/blob/main/designs/2022-06-07-bazel-credential-helpers.md
[cred-helper-spec]: https://github.com/EngFlow/credential-helper-spec/blob/main/spec.md


### Basic Example:

The simplest form of a credential helper is a bash script that accepts an arg and spits out JSON to
stdout. For a service like Google Artifact Registry that uses ['Basic' HTTP Auth][rfc7617] and does
not provide a credential helper that conforms to the [spec][cred-helper-spec], the script might
look like:

```bash
#!/bin/bash
# cred_helper.sh
ARG=$1  # but we don't do anything with it as it's always "get"

# formatting is optional
echo '{'
echo '  "headers": {'
echo '    "Authorization": ["Basic dGVzdDoxMjPCow=="]
echo '  }'
echo '}'
```

Configure Bazel to use this credential helper for your python index `example.com`:

```
# .bazelrc
build --credential_helper=example.com=/full/path/to/cred_helper.sh
```

Bazel will call this file like `cred_helper.sh get` and use the returned JSON to inject headers
into whatever HTTP(S) request it performs against `example.com`.

[rfc7617]: https://datatracker.ietf.org/doc/html/rfc7617
