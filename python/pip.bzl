# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Import pip requirements into Bazel."""

load("//python/pip_install:pip_repository.bzl", "pip_repository", _package_annotation = "package_annotation")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/pip_install:requirements.bzl", _compile_pip_requirements = "compile_pip_requirements")

compile_pip_requirements = _compile_pip_requirements
package_annotation = _package_annotation

def pip_install(requirements = None, name = "pip", **kwargs):
    # pip_install is now considered deprecated.
    # In future, this may log a warning and eventually be removed.
    pip_parse(requirements = requirements, name = name, **kwargs)

def pip_parse(requirements = None, requirements_lock = None, name = "pip_parsed_deps", **kwargs):
    """Accepts a locked/compiled requirements file and installs the dependencies listed within.

    Those dependencies become available in a generated `requirements.bzl` file.
    You can instead check this `requirements.bzl` file into your repo, see the "vendoring" section below.

    This macro wraps the [`pip_repository`](./pip_repository.md) rule that invokes `pip`, with `incremental` set.
    In your WORKSPACE file:

    ```python
    load("@rules_python//python:pip.bzl", "pip_parse")

    pip_parse(
        name = "pip_deps",
        requirements_lock = ":requirements.txt",
    )

    load("@pip_deps//:requirements.bzl", "install_deps")

    install_deps()
    ```

    You can then reference installed dependencies from a `BUILD` file with:

    ```python
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

    ```python
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

    ```python
    load("@pip_deps//:requirements.bzl", "entry_point")

    alias(
        name = "flake8",
        actual = entry_point("flake8"),
    )
    ```

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

    Args:
        requirements_lock (Label): A fully resolved 'requirements.txt' pip requirement file
            containing the transitive set of your dependencies. If this file is passed instead
            of 'requirements' no resolve will take place and pip_repository will create
            individual repositories for each of your dependencies so that wheels are
            fetched/built only for the targets specified by 'build/run/test'.
            Note that if your lockfile is platform-dependent, you can use the `requirements_[platform]`
            attributes.
        requirements (Label): Deprecated. See requirements_lock.
        name (str, optional): The name of the generated repository. The generated repositories
            containing each requirement will be of the form <name>_<requirement-name>.
        **kwargs (dict): Additional arguments to the [`pip_repository`](./pip_repository.md) repository rule.
    """

    # Just in case our dependencies weren't already fetched
    pip_install_dependencies()

    # Temporary compatibility shim
    # pip_install was previously document to use requirements while pip_parse was using requirements_lock
    # We would prefer everyone move to using requirements_lock, but we maintain a temporary shim
    reqs_to_use = requirements_lock if requirements_lock else requirements

    pip_repository(
        name = name,
        requirements_lock = reqs_to_use,
        repo_prefix = "{}_".format(name),
        **kwargs
    )
