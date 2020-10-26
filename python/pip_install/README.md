# rules_python_external ![](https://github.com/dillon-giacoppo/rules_python_external/workflows/CI/badge.svg)

Bazel rules to transitively fetch and install Python dependencies from a requirements.txt file.

## Features

The rules address most of the top packaging issues in [`bazelbuild/rules_python`](https://github.com/bazelbuild/rules_python). This means the rules support common packages such
as [`tensorflow`](https://pypi.org/project/tensorflow/) and [`google.cloud`](https://github.com/googleapis/google-cloud-python) natively.

* Transitive dependency resolution:
    [#35](https://github.com/bazelbuild/rules_python/issues/35),
    [#102](https://github.com/bazelbuild/rules_python/issues/102)
* Minimal runtime dependencies:
    [#184](https://github.com/bazelbuild/rules_python/issues/184)
* Support for [spreading purelibs](https://www.python.org/dev/peps/pep-0491/#installing-a-wheel-distribution-1-0-py32-none-any-whl):
    [#71](https://github.com/bazelbuild/rules_python/issues/71)
* Support for [namespace packages](https://packaging.python.org/guides/packaging-namespace-packages/):
    [#14](https://github.com/bazelbuild/rules_python/issues/14),
    [#55](https://github.com/bazelbuild/rules_python/issues/55),
    [#65](https://github.com/bazelbuild/rules_python/issues/65),
    [#93](https://github.com/bazelbuild/rules_python/issues/93),
    [#189](https://github.com/bazelbuild/rules_python/issues/189)
* Fetches pip packages only for building Python targets:
    [#96](https://github.com/bazelbuild/rules_python/issues/96)
* Reproducible builds:
    [#154](https://github.com/bazelbuild/rules_python/issues/154),
    [#176](https://github.com/bazelbuild/rules_python/issues/176)

## Usage

#### Prerequisites

The rules support Python >= 3.5 (the oldest [maintained release](https://devguide.python.org/#status-of-python-branches)).

#### Setup `WORKSPACE`

```python
rules_python_external_version = "{COMMIT_SHA}"

http_archive(
    name = "rules_python_external",
    sha256 = "", # Fill in with correct sha256 of your COMMIT_SHA version
    strip_prefix = "rules_python_external-{version}".format(version = rules_python_external_version),
    url = "https://github.com/dillon-giacoppo/rules_python_external/archive/v{version}.zip".format(version = rules_python_external_version),
)

# Install the rule dependencies
load("@rules_python_external//:repositories.bzl", "rules_python_external_dependencies")
rules_python_external_dependencies()

load("@rules_python_external//:defs.bzl", "pip_install")
pip_install(
    name = "py_deps",
    requirements = "//:requirements.txt",
    # (Optional) You can provide a python interpreter (by path):
    python_interpreter = "/usr/bin/python3.8",
    # (Optional) Alternatively you can provide an in-build python interpreter, that is available as a Bazel target.
    # This overrides `python_interpreter`.
    # Note: You need to set up the interpreter target beforehand (not shown here). Please see the `example` folder for further details.
    #python_interpreter_target = "@python_interpreter//:python_bin",
)
```

#### Example `BUILD` file.

```python
load("@py_deps//:requirements.bzl", "requirement", "whl_requirement")

py_binary(
    name = "main",
    srcs = ["main.py"],
    deps = [
        requirement("boto3"),
    ]
)

# If you need to depend on the wheel dists themselves, for instance to pass them
# to some other packaging tool, you can get a handle to them with the whl_requirement macro.
filegroup(
    name = "whl_files",
    data = [
        whl_requirement("boto3"),
    ]
)
```

Note that above you do not need to add transitively required packages to `deps = [ ... ]` or `data = [ ... ]`

#### Setup `requirements.txt`

While `rules_python_external` **does not** require a _transitively-closed_ `requirements.txt` file, it is recommended.
But if you want to just have top-level packages listed, that also will work.

Transitively-closed requirements specs are very tedious to produce and maintain manually. To automate the process we
recommend [`pip-compile` from `jazzband/pip-tools`](https://github.com/jazzband/pip-tools#example-usage-for-pip-compile).

For example, `pip-compile` takes a `requirements.in` like this:

```
boto3~=1.9.227
botocore~=1.12.247
click~=7.0
```

`pip-compile` 'compiles' it so you get a transitively-closed `requirements.txt` like this, which should be passed to
`pip_install` below:

```
boto3==1.9.253
botocore==1.12.253
click==7.0
docutils==0.15.2          # via botocore
jmespath==0.9.4           # via boto3, botocore
python-dateutil==2.8.1    # via botocore
s3transfer==0.2.1         # via boto3
six==1.14.0               # via python-dateutil
urllib3==1.25.8           # via botocore
```

### Demo

You can find a demo in the [example/](./example) directory.

## Development

### Testing

`bazel test //...`

## Adopters

Here's a (non-exhaustive) list of companies that use `rules_python_external` in production. Don't see yours? [You can add it in a PR](https://github.com/dillon-giacoppo/rules_python_external/edit/master/README.md)!

* [Canva](https://www.canva.com/)
