# Using dependencies from PyPI

Using PyPI packages (aka "pip install") involves two main steps.

1. [Installing third party packages](#installing-third-party-packages)
2. [Using third party packages as dependencies](#using-third-party-packages-as-dependencies)

## Installing third party packages

### Using bzlmod

To add pip dependencies to your `MODULE.bazel` file, use the `pip.parse`
extension, and call it to create the central external repo and individual wheel
external repos. Include in the `MODULE.bazel` the toolchain extension as shown
in the first bzlmod example above.

```starlark
pip = use_extension("@rules_python//python/extensions:pip.bzl", "pip")
pip.parse(
    hub_name = "my_deps",
    python_version = "3.11",
    requirements_lock = "//:requirements_lock_3_11.txt",
)
use_repo(pip, "my_deps")
```
For more documentation, including how the rules can update/create a requirements
file, see the bzlmod examples under the {gh-path}`examples` folder.

### Using a WORKSPACE file

To add pip dependencies to your `WORKSPACE`, load the `pip_parse` function and
call it to create the central external repo and individual wheel external repos.

```starlark
load("@rules_python//python:pip.bzl", "pip_parse")

# Create a central repo that knows about the dependencies needed from
# requirements_lock.txt.
pip_parse(
   name = "my_deps",
   requirements_lock = "//path/to:requirements_lock.txt",
)
# Load the starlark macro, which will define your dependencies.
load("@my_deps//:requirements.bzl", "install_deps")
# Call it to define repos for your requirements.
install_deps()
```

### pip rules

Note that since `pip_parse` is a repository rule and therefore executes pip at
WORKSPACE-evaluation time, Bazel has no information about the Python toolchain
and cannot enforce that the interpreter used to invoke pip matches the
interpreter used to run `py_binary` targets. By default, `pip_parse` uses the
system command `"python3"`. To override this, pass in the `python_interpreter`
attribute or `python_interpreter_target` attribute to `pip_parse`.

You can have multiple `pip_parse`s in the same workspace.  Or use the pip
extension multiple times when using bzlmod. This configuration will create
multiple external repos that have no relation to one another and may result in
downloading the same wheels numerous times.

As with any repository rule, if you would like to ensure that `pip_parse` is
re-executed to pick up a non-hermetic change to your environment (e.g., updating
your system `python` interpreter), you can force it to re-execute by running
`bazel sync --only [pip_parse name]`.

:::{note}
The `pip_install` rule is deprecated. `pip_parse` offers identical
functionality, and both `pip_install` and `pip_parse` now have the same
implementation. The name `pip_install` may be removed in a future version of the
rules.
:::

The maintainers have made all reasonable efforts to facilitate a smooth
transition. Still, some users of `pip_install` will need to replace their
existing `requirements.txt` with a fully resolved set of dependencies using a
tool such as `pip-tools` or the `compile_pip_requirements` repository rule.

## Using third party packages as dependencies

Each extracted wheel repo contains a `py_library` target representing
the wheel's contents. There are two ways to access this library. The
first uses the `requirement()` function defined in the central
repo's `//:requirements.bzl` file. This function maps a pip package
name to a label:

```starlark
load("@my_deps//:requirements.bzl", "requirement")

py_library(
    name = "mylib",
    srcs = ["mylib.py"],
    deps = [
        ":myotherlib",
        requirement("some_pip_dep"),
        requirement("another_pip_dep"),
    ]
)
```

The reason `requirement()` exists is to insulate from
changes to the underlying repository and label strings. However, those
labels have become directly used, so aren't able to easily change regardless.

On the other hand, using `requirement()` has several drawbacks; see
[this issue][requirements-drawbacks] for an enumeration. If you don't
want to use `requirement()`, you can use the library
labels directly instead. For `pip_parse`, the labels are of the following form:

```starlark
@{name}_{package}//:pkg
```

Here `name` is the `name` attribute that was passed to `pip_parse` and
`package` is the pip package name with characters that are illegal in
Bazel label names (e.g. `-`, `.`) replaced with `_`. If you need to
update `name` from "old" to "new", then you can run the following
buildozer command:

```shell
buildozer 'substitute deps @old_([^/]+)//:pkg @new_${1}//:pkg' //...:*
```

[requirements-drawbacks]: https://github.com/bazelbuild/rules_python/issues/414

### 'Extras' dependencies

Any 'extras' specified in the requirements lock file will be automatically added
as transitive dependencies of the package. In the example above, you'd just put
`requirement("useful_dep")`.

### Packaging cycles

Sometimes PyPi packages contain dependency cycles -- for instance `sphinx`
depends on `sphinxcontrib-serializinghtml`. When using them as `requirement()`s,
ala

```
py_binary(
  name = "doctool",
  ...
  deps = [
    requirement("sphinx"),
   ]
)
```

Bazel will protest because it doesn't support cycles in the build graph --

```
ERROR: .../external/pypi_sphinxcontrib_serializinghtml/BUILD.bazel:44:6: in alias rule @pypi_sphinxcontrib_serializinghtml//:pkg: cycle in dependency graph:
    //:doctool (...)
    @pypi//sphinxcontrib_serializinghtml:pkg (...)
.-> @pypi_sphinxcontrib_serializinghtml//:pkg (...)
|   @pypi_sphinxcontrib_serializinghtml//:_pkg (...)
|   @pypi_sphinx//:pkg (...)
|   @pypi_sphinx//:_pkg (...)
`-- @pypi_sphinxcontrib_serializinghtml//:pkg (...)
```

The `requirement_cycles` argument allows you to work around these issues by
specifying groups of packages which form cycles. `pip_parse` will transparently
fix the cycles for you and provide the cyclic dependencies simultaneously.

```
pip_parse(
  ...
  requirement_cycles = {
    "sphinx": [
      "sphinx",
      "sphinxcontrib-serializinghtml",
    ]
  },
)
```

`pip_parse` supports fixing multiple cycles simultaneously, however cycles must
be distinct. `apache-airflow` for instance has dependency cycles with a number
of its optional dependencies, which means those optional dependencies must all
be a part of the `airflow` cycle. For instance --

```
pip_parse(
  ...
  requirement_cycles = {
    "airflow": [
      "apache-airflow",
      "apache-airflow-providers-common-sql",
      "apache-airflow-providers-postgres",
      "apache-airflow-providers-sqlite",
    ]
  }
)
```

Alternatively, one could resolve the cycle by removing one leg of it.

For example while `apache-airflow-providers-sqlite` is "baked into" the Airflow
package, `apache-airflow-providers-postgres` is not and is an optional feature.
Rather than listing `apache-airflow[postgres]` in your `requirements.txt` which
would expose a cycle via the extra, one could either _manually_ depend on
`apache-airflow` and `apache-airflow-providers-postgres` separately as
requirements. Bazel rules which need only `apache-airflow` can take it as a
dependency, and rules which explicitly want to mix in
`apache-airflow-providers-postgres` now can.

Alternatively, one could use `rules_python`'s patching features to remove one
leg of the dependency manually. For instance by making
`apache-airflow-providers-postgres` not explicitly depend on `apache-airflow` or
perhaps `apache-airflow-providers-common-sql`.

## Consuming Wheel Dists Directly

If you need to depend on the wheel dists themselves, for instance, to pass them
to some other packaging tool, you can get a handle to them with the
`whl_requirement` macro. For example:

```starlark
filegroup(
    name = "whl_files",
    data = [
        whl_requirement("boto3"),
    ]
)
```
