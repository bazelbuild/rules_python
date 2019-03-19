# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Rules for building wheels."""

def _py_wheel_impl(ctx):
    outfile = ctx.actions.declare_file("-".join([
        ctx.attr.distribution,
        ctx.attr.version,
        ctx.attr.python_tag,
        ctx.attr.abi,
        ctx.attr.platform,
    ]) + ".whl")

    inputs = depset(
        transitive = [dep[DefaultInfo].data_runfiles.files for dep in ctx.attr.deps] +
                     [dep[DefaultInfo].default_runfiles.files for dep in ctx.attr.deps],
    )
    arguments = [
        "--name",
        ctx.attr.distribution,
        "--version",
        ctx.attr.version,
        "--python_tag",
        ctx.attr.python_tag,
        "--abi",
        ctx.attr.abi,
        "--platform",
        ctx.attr.platform,
        "--out",
        outfile.path,
    ]
    arguments.extend(["--restrict_package=%s" % p for p in ctx.attr.packages])
    for input_file in inputs.to_list():
        arguments.append("--input_file")
        arguments.append("%s;%s" % (input_file.short_path, input_file.path))

    extra_headers = []
    if ctx.attr.author:
        extra_headers.append("Author: %s" % ctx.attr.author)
    if ctx.attr.author_email:
        extra_headers.append("Author-email: %s" % ctx.attr.author_email)
    if ctx.attr.homepage:
        extra_headers.append("Home-page: %s" % ctx.attr.homepage)
    if ctx.attr.license:
        extra_headers.append("License: %s" % ctx.attr.license)

    for h in extra_headers:
        arguments.append("--header")
        arguments.append(h)

    for c in ctx.attr.classifiers:
        arguments.append("--classifier")
        arguments.append(c)

    for r in ctx.attr.requires:
        arguments.append("--requires")
        arguments.append(r)

    for option, requirements in ctx.attr.extra_requires.items():
        for r in requirements:
            arguments.append("--extra_requires")
            arguments.append(r + ";" + option)

    for name, ref in ctx.attr.console_scripts.items():
        arguments.append("--console_script")
        arguments.append(name + " = " + ref)

    if ctx.attr.description_file:
        description_files = ctx.attr.description_file.files.to_list()
        arguments.append("--description_file")
        arguments.append(description_files[0].path)
        inputs = inputs.union(ctx.attr.description_file.files)

    ctx.actions.run(
        inputs = inputs,
        outputs = [outfile],
        arguments = arguments,
        executable = ctx.executable._wheelmaker,
        progress_message = "Building wheel",
    )
    return [DefaultInfo(
        files = depset([outfile]),
        data_runfiles = ctx.runfiles(files = [outfile]),
    )]

py_wheel = rule(
    implementation = _py_wheel_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "Dependencies of this package, e.g. py_library rules",
        ),
        "packages": attr.string_list(
            mandatory = True,
            allow_empty = False,
            doc = """\
List of Python packages to include in the distribution.
Sub-packages are automatically included.
""",
        ),
        # Attributes defining the distribution
        "distribution": attr.string(
            mandatory = True,
            doc = "Name of the wheel",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Version number of the package",
        ),
        "python_tag": attr.string(
            default = "py3",
            doc = "Supported Python major version. 'py2' or 'py3'",
        ),
        "abi": attr.string(
            default = "none",
            doc = "Python ABI tag. 'none' for pure-Python wheels.",
        ),
        # TODO(pstradomski): Support non-pure wheels
        "platform": attr.string(
            default = "any",
            doc = "Supported platforms. 'any' for pure-Python wheel.",
        ),
        # Other attributes
        "author": attr.string(default = ""),
        "author_email": attr.string(default = ""),
        "homepage": attr.string(default = ""),
        "license": attr.string(default = ""),
        "classifiers": attr.string_list(),
        "description_file": attr.label(allow_files = True),
        # Requirements
        "requires": attr.string_list(
            doc = "List of requirements for this package",
        ),
        "extra_requires": attr.string_list_dict(
            doc = "List of optional requirements for this package",
        ),
        # Entry points
        "console_scripts": attr.string_dict(
            doc = "console_script entry points",
        ),
        # Implementation details.
        "_wheelmaker": attr.label(
            executable = True,
            cfg = "host",
            default = "//experimental/rules_python:wheelmaker",
        ),
    },
)
