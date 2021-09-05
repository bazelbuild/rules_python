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

load("//python/pip_install:pip_repository.bzl", "pip_repository")
load("//python/pip_install:repositories.bzl", "pip_install_dependencies")

def pip_install(requirements, name = "pip", **kwargs):
    """Imports a `requirements.txt` file and generates a new `requirements.bzl` file.

    This is used via the `WORKSPACE` pattern:

    ```python
    pip_install(
        requirements = ":requirements.txt",
    )
    ```

    You can then reference imported dependencies from your `BUILD` file with:

    ```python
    load("@pip//:requirements.bzl", "requirement")
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

    Note that for packages who's name and script are the same, only the name of the package
    is needed when calling the `entry_point` macro.

    ```python
    load("@pip_deps//:requirements.bzl", "entry_point")

    alias(
        name = "flake8",
        actual = entry_point("flake8"),
    )
    ```

    Args:
        requirements: A 'requirements.txt' pip requirements file.
        name: A unique name for the created external repository (default 'pip').
        **kwargs: Keyword arguments passed directly to the `pip_repository` repository rule.
    """

    # Just in case our dependencies weren't already fetched
    pip_install_dependencies()

    pip_repository(
        name = name,
        requirements = requirements,
        **kwargs
    )

def pip_parse(requirements_lock, name = "pip_parsed_deps", **kwargs):
    """Imports a locked/compiled requirements file and generates a new `requirements.bzl` file.

    This is used via the `WORKSPACE` pattern:

    ```python
    load("@rules_python//python:pip.bzl", "pip_parse")

    pip_parse(
        name = "pip_deps",
        requirements_lock = ":requirements.txt",
    )

    load("@pip_deps//:requirements.bzl", "install_deps")

    install_deps()
    ```

    You can then reference imported dependencies from your `BUILD` file with:

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

    Note that for packages who's name and script are the same, only the name of the package
    is needed when calling the `entry_point` macro.

    ```python
    load("@pip_deps//:requirements.bzl", "entry_point")

    alias(
        name = "flake8",
        actual = entry_point("flake8"),
    )
    ```

    Args:
        requirements_lock (Label): A fully resolved 'requirements.txt' pip requirement file
            containing the transitive set of your dependencies. If this file is passed instead
            of 'requirements' no resolve will take place and pip_repository will create
            individual repositories for each of your dependencies so that wheels are
            fetched/built only for the targets specified by 'build/run/test'.
        name (str, optional): The name of the generated repository.
        **kwargs (dict): Additional keyword arguments for the underlying
            `pip_repository` rule.
    """

    # Just in case our dependencies weren't already fetched
    pip_install_dependencies()

    pip_repository(
        name = name,
        requirements_lock = requirements_lock,
        incremental = True,
        **kwargs
    )

def pip_repositories():
    # buildifier: disable=print
    print("DEPRECATED: the pip_repositories rule has been replaced with pip_install, please see rules_python 0.1 release notes")

def pip_import(**kwargs):
    fail("=" * 79 + """\n
    pip_import has been replaced with pip_install, please see the rules_python 0.1 release notes.
    To continue using it, you can load from "@rules_python//python/legacy_pip_import:pip.bzl"
    """)
