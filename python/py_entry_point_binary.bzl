# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
A macro to generate an entry_point from reading the 'console_scripts'.

We can specifically request the entry_point to be running with e.g. Python 3.9:
```starlark
load("@python_versions//3.9:defs.bzl", "entry_point")

entry_point(
    name = "yamllint",
    pkg = "@pip//yamllint",
    # yamllint does not have any other scripts except 'yamllint' so the
    # user does not have to specify which console script we should chose from
    # the package.
)
```

Or just use the default version:
```starlark
load("@rules_python//python:py_entry_point_binary.bzl", "entry_point")

entry_point(
    name = "pylint",
    pkg = "@pip//pylint",
    # Because `pylint` has multiple console_scripts available, we have to
    # specify which we want
    script = "pylint",
    deps = [
        # One can add extra dependencies to the entry point.
        # This specifically allows us to add plugins to pylint.
        "@pip//pylint_print",
    ],
)
```
"""

load("//python:py_binary.bzl", "py_binary")

_tool = Label("//python/pip_install/tools/entry_point_generator")

def entry_point(*, name, pkg, script = None, deps = None, **kwargs):
    """Generate an entry_point for a given package

    Args:
        name: The name of the resultant py_binary target.
        pkg: The package for which to generate the script.
        script: The console script that the entry_point is going to be
            generated. Mandatory if there are more than 1 console_script in the
            package.
        deps: The extra dependencies to add to the py_binary rule.
        **kwargs: Extra parameters forwarded to py_binary.
    """
    main = "rules_python_entry_point_{}.py".format(name)

    # TODO @aignas 2023-08-05: Ideally this could be implemented as a rule that is using
    # the Python toolchain, but this should be functional and establish the API.
    native.genrule(
        name = name + "_gen",
        cmd = "$(location {tool}) {args} $(SRCS) --out $@".format(
            tool = _tool,
            args = "--script=" + script if script else "",
        ),
        # NOTE @aignas 2023-08-05: This should work with
        # `incompatible_generate_aliases` and without.
        srcs = [
            pkg.replace(":pkg", "") + ":dist_info",
        ],
        outs = [main],
        tools = [_tool],
        executable = True,
        visibility = ["//visibility:private"],
    )

    entry_point_deps = [pkg]
    if deps:
        entry_point_deps.extend(deps)

    # This may come via transitions, so ensure that we are not using it at all.
    _ = kwargs.pop("srcs", None)  # buildifier: disable=unused-variable
    _ = kwargs.pop("main", None)  # buildifier: disable=unused-variable

    py_binary(
        name = name,
        srcs = [main],
        main = main,
        deps = entry_point_deps,
        **kwargs
    )
