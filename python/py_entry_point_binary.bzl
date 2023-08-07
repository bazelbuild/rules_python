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

def _impl(ctx):
    args = ctx.actions.args()
    args.add("--script", ctx.attr.script)
    args.add("--out", ctx.outputs.out)
    args.add_all(ctx.files.dist_info)

    ctx.actions.run(
        inputs = ctx.files.dist_info,
        outputs = [ctx.outputs.out],
        arguments = [args],
        executable = ctx.executable._tool,
    )

    return [DefaultInfo(
        files = depset([ctx.outputs.out]),
    )]

_gen_entry_point = rule(
    _impl,
    attrs = {
        "dist_info": attr.label(
            doc = "The dist-info files for the package.",
            mandatory = True,
        ),
        "out": attr.output(
            doc = "Output file location.",
            mandatory = True,
        ),
        "script": attr.string(
            doc = "The script to create the entry_point script for.",
            default = "",
        ),
        "_tool": attr.label(
            default = "//python/pip_install/tools/entry_point_generator",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Builds an entry_point script from an entry_points.txt file.",
)

def py_entry_point_binary(*, name, pkg, script = None, deps = None, binary_rule = py_binary, **kwargs):
    """Generate an entry_point for a given package

    Args:
        name: The name of the resultant binary_rule target.
        pkg: The package for which to generate the script.
        script: The console script that the entry_point is going to be
            generated. Mandatory if there are more than 1 console_script in the
            package.
        binary_rule: The binary rule to call to create the entry_point binary.
            Defaults to @rules_python//python:py_binary.bzl#py_binary.
        deps: The extra dependencies to add to the binary_rule rule.
        **kwargs: Extra parameters forwarded to binary_rule.
    """
    main = "rules_python_entry_point_{}.py".format(name)

    _gen_entry_point(
        name = name + "_gen",
        # NOTE @aignas 2023-08-05: Works with `incompatible_generate_aliases` and without.
        dist_info = pkg.replace(":pkg", "") + ":dist_info",
        out = main,
        script = script,
    )

    entry_point_deps = [pkg]
    if deps:
        entry_point_deps.extend(deps)

    # This may come via transitions, so ensure that we are not using it at all.
    _ = kwargs.pop("srcs", None)  # buildifier: disable=unused-variable
    _ = kwargs.pop("main", None)  # buildifier: disable=unused-variable

    binary_rule(
        name = name,
        srcs = [main],
        main = main,
        deps = entry_point_deps,
        **kwargs
    )
