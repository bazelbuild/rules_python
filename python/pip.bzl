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
load(":versions.bzl", "MINOR_MAPPING", "PLATFORMS")

compile_pip_requirements = _compile_pip_requirements
package_annotation = _package_annotation

def pip_install(requirements = None, name = "pip", **kwargs):
    """Accepts a locked/compiled requirements file and installs the dependencies listed within.

    ```python
    load("@rules_python//python:pip.bzl", "pip_install")

    pip_install(
        name = "pip_deps",
        requirements = ":requirements.txt",
    )

    load("@pip_deps//:requirements.bzl", "install_deps")

    install_deps()
    ```

    Args:
        requirements (Label): A 'requirements.txt' pip requirements file.
        name (str, optional): A unique name for the created external repository (default 'pip').
        **kwargs (dict): Additional arguments to the [`pip_repository`](./pip_repository.md) repository rule.
    """

    # buildifier: disable=print
    print("pip_install is deprecated. Please switch to pip_parse. pip_install will be removed in a future release.")
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

    # Temporary compatibility shim.
    # pip_install was previously document to use requirements while pip_parse was using requirements_lock.
    # We would prefer everyone move to using requirements_lock, but we maintain a temporary shim.
    reqs_to_use = requirements_lock if requirements_lock else requirements

    pip_repository(
        name = name,
        requirements_lock = reqs_to_use,
        repo_prefix = "{}_".format(name),
        **kwargs
    )

def _multi_pip_parse_impl(rctx):
    rules_python = rctx.attr._rules_python_workspace.workspace_name
    load_statements = []
    install_deps_calls = []
    process_requirements_calls = []
    for python_version, pypi_repository in rctx.attr.pip_parses.items():
        sanitized_python_version = python_version.replace(".", "_")
        load_statement = """\
load(
    "@{pypi_repository}//:requirements.bzl",
    _{sanitized_python_version}_install_deps = "install_deps",
    _{sanitized_python_version}_all_requirements = "all_requirements",
    _{sanitized_python_version}_all_whl_requirements = "all_whl_requirements",
)""".format(
            pypi_repository = pypi_repository,
            sanitized_python_version = sanitized_python_version,
        )
        load_statements.append(load_statement)
        process_requirements_call = """\
_process_requirements(
    pkg_labels = _{sanitized_python_version}_all_requirements,
    python_version = "{python_version}",
    repo_prefix = "{pypi_repository}_",
)""".format(
            pypi_repository = pypi_repository,
            python_version = python_version,
            sanitized_python_version = sanitized_python_version,
        )
        process_requirements_calls.append(process_requirements_call)
        install_deps_call = """    _{sanitized_python_version}_install_deps(**whl_library_kwargs)""".format(
            sanitized_python_version = sanitized_python_version,
        )
        install_deps_calls.append(install_deps_call)

    requirements_bzl = """\
# Generated by python/pip.bzl

load("@{rules_python}//python:pip.bzl", "whl_library_alias")
{load_statements}

_wheel_names = []
_version_map = dict()
def _process_requirements(pkg_labels, python_version, repo_prefix):
    for pkg_label in pkg_labels:
        workspace_name = Label(pkg_label).workspace_name
        wheel_name = workspace_name[len(repo_prefix):]
        _wheel_names.append(wheel_name)
        if not wheel_name in _version_map:
            _version_map[wheel_name] = dict()
        _version_map[wheel_name][python_version] = pkg_label

{process_requirements_calls}

def _clean_name(name):
    return name.replace("-", "_").replace(".", "_").lower()

def requirement(name):
    return "@{name}//pkg:" + _clean_name(name)

def whl_requirement(name):
    return "@{name}//whl:" + _clean_name(name)

def data_requirement(name):
    return "@{name}//data:" + _clean_name(name)

def dist_info_requirement(name):
    return "@{name}//dist_info:" + _clean_name(name)

def entry_point(pkg, script = None):
    fail("Not implemented yet")

def install_deps(**whl_library_kwargs):
{install_deps_calls}
    for wheel_name in _wheel_names:
        whl_library_alias(
            name = "{name}_" + wheel_name,
            wheel_name = wheel_name,
            default_version = "{default_version}",
            version_map = _version_map[wheel_name],
        )
        # print(_all_requirements[name])
""".format(
        name = rctx.attr.name,
        install_deps_calls = "\n".join(install_deps_calls),
        load_statements = "\n".join(load_statements),
        process_requirements_calls = "\n".join(process_requirements_calls),
        rules_python = rules_python,
        default_version = rctx.attr.default_version,
    )
    rctx.file("requirements.bzl", requirements_bzl)
    rctx.file("BUILD.bazel", "exports_files(['requirements.bzl'])")

_multi_pip_parse = repository_rule(
    _multi_pip_parse_impl,
    attrs = {
        "default_version": attr.string(),
        "pip_parses": attr.string_dict(),
        "_rules_python_workspace": attr.label(default = Label("//:WORKSPACE")),
    },
)

def _whl_library_alias_impl(rctx):
    rules_python = rctx.attr._rules_python_workspace.workspace_name
    build_content = ["""\
# Generated by python/pip.bzl

alias(
    name = "pkg",
    actual = select({
"""]
    for [platform_name, meta] in PLATFORMS.items():
        for [python_version, actual] in rctx.attr.version_map.items():
            build_content.append("""\
        "@{rules_python}//python/platforms:{platform_name}_{full_python_version}_config": "{actual}",
""".format(
                full_python_version = MINOR_MAPPING[python_version] if python_version in MINOR_MAPPING else python_version,
                platform_name = platform_name,
                actual = actual,
                rules_python = rules_python,
            ))
    build_content.append("""\
        "//conditions:default": "{default_actual}",
    }}),
    visibility = ["//visibility:public"],
)""".format(
        default_actual = rctx.attr.version_map[rctx.attr.default_version],
    ))
    rctx.file("BUILD.bazel", "\n".join(build_content))

whl_library_alias = repository_rule(
    _whl_library_alias_impl,
    attrs = {
        "default_version": attr.string(mandatory = True),
        "version_map": attr.string_dict(mandatory = True),
        "wheel_name": attr.string(mandatory = True),
        "_rules_python_workspace": attr.label(default = Label("//:WORKSPACE")),
    },
)

def multi_pip_parse(name, default_version, python_versions, requirements_lock, **kwargs):
    """NOT INTENDED FOR DIRECT USE!

    This is intended to be used by the multi_pip_parse implementation in the template of the
    multi_toolchain_aliases repository rule.

    Args:
        name: the name of the multi_pip_parse repository.
        default_version: the default Python version.
        python_versions: all Python toolchain versions currently registered.
        requirements_lock: a dictionary which keys are Python versions and values are locked requirements files.
        **kwargs: extra arguments passed to all wrapped pip_parse.

    Returns:
        The internal implementation of multi_pip_parse repository rule.
    """
    pip_parses = {}
    for python_version in python_versions:
        if not python_version in requirements_lock:
            fail("Missing requirements_lock for Python version %s in '%s'" % (python_version, name))

        pip_parse_name = name + "_" + python_version.replace(".", "_")
        pip_parse(
            name = pip_parse_name,
            requirements_lock = requirements_lock[python_version],
            **kwargs
        )
        pip_parses[python_version] = pip_parse_name

    return _multi_pip_parse(
        name = name,
        default_version = default_version,
        pip_parses = pip_parses,
    )
