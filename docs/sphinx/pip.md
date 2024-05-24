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

For `bzlmod` an equivalent `MODULE.bazel` would look like:
```starlark
pip = use_extension("//python/extensions:pip.bzl", "pip")
pip.parse(
    hub_name = "pip_deps",
    requirements_lock = ":requirements.txt",
)
use_repo(pip, "pip_deps")
```

You can then reference installed dependencies from a `BUILD` file with:

```starlark
load("@pip_deps//:requirements.bzl", "requirement")

py_library(
    name = "bar",
    ...
    deps = [
        "//my/other:dep",
        "@pip_deps//requests",
        "@pip_deps//numpy",
    ],
)
```

The rules also provide a convenience macro for translating the entries in the
`requirements.txt` file (e.g. `opencv-python`) to the right bazel label (e.g.
`@pip_deps//opencv_python`). The convention of bazel labels is lowercase
`snake_case`, but you can use the helper to avoid depending on this convention
as follows:

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

If you would like to access [entry points][whl_ep], see the `py_console_script_binary` rule documentation.

[whl_ep]: https://packaging.python.org/specifications/entry-points/

(per-os-arch-requirements)=
## Requirements for a specific OS/Architecture

In some cases you may need to use different requirements files for different OS, Arch combinations. This is enabled via the `requirements_by_platform` attribute in `pip.parse` extension and the `pip_parse` repository rule. The keys of the dictionary are labels to the file and the values are a list of comma separated target (os, arch) tuples.

For example:
```starlark
    # ...
    requirements_by_platform = {
        "requirements_linux_x86_64.txt": "linux_x86_64",
        "requirements_osx.txt": "osx_*",
        "requirements_linux_exotic.txt": "linux_exotic",
        "requirements_some_platforms.txt": "linux_aarch64,windows_*",
    },
    # For the list of standard platforms that the rules_python has toolchains for, default to
    # the following requirements file.
    requirements_lock = "requirements_lock.txt",
```

In case of duplicate platforms, `rules_python` will raise an error as there has
to be unambiguous mapping of the requirement files to the (os, arch) tuples.

An alternative way is to use per-OS requirement attributes.
```starlark
    # ...
    requirements_windows = "requirements_windows.txt",
    requirements_darwin = "requirements_darwin.txt",
    # For the remaining platforms (which is basically only linux OS), use this file.
    requirements_lock = "requirements_lock.txt",
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
echo '    "Authorization": ["Basic dGVzdDoxMjPCow=="]'
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
