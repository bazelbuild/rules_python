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

def pip_install_incremental(requirements_lock, name = "pip_incremental", **kwargs):
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
