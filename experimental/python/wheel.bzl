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

def _path_inside_wheel(input_file):
    # input_file.short_path is sometimes relative ("../${repository_root}/foobar")
    # which is not a valid path within a zip file. Fix that.
    short_path = input_file.short_path
    if short_path.startswith("..") and len(short_path) >= 3:
        # Path separator. '/' on linux.
        separator = short_path[2]

        # Consume '../' part.
        short_path = short_path[3:]

        # Find position of next '/' and consume everything up to that character.
        pos = short_path.find(separator)
        short_path = short_path[pos + 1:]
    return short_path

def _input_file_to_arg(input_file):
    """Converts a File object to string for --input_file argument to wheelmaker"""
    return "%s;%s" % (_path_inside_wheel(input_file), input_file.path)

def _py_package_impl(ctx):
    inputs = depset(
        transitive = [dep[DefaultInfo].data_runfiles.files for dep in ctx.attr.deps] +
                     [dep[DefaultInfo].default_runfiles.files for dep in ctx.attr.deps],
    )

    # TODO: '/' is wrong on windows, but the path separator is not available in starlark.
    # Fix this once ctx.configuration has directory separator information.
    packages = [p.replace(".", "/") for p in ctx.attr.packages]
    if not packages:
        filtered_inputs = inputs
    else:
        filtered_files = []

        # TODO: flattening depset to list gives poor performance,
        for input_file in inputs.to_list():
            wheel_path = _path_inside_wheel(input_file)
            for package in packages:
                if wheel_path.startswith(package):
                    filtered_files.append(input_file)
        filtered_inputs = depset(direct = filtered_files)

    return [DefaultInfo(
        files = filtered_inputs,
    )]

py_package = rule(
    implementation = _py_package_impl,
    doc = """
A rule to select all files in transitive dependencies of deps which
belong to given set of Python packages.

This rule is intended to be used as data dependency to py_wheel rule
""",
    attrs = {
        "deps": attr.label_list(),
        "packages": attr.string_list(
            mandatory = False,
            allow_empty = True,
            doc = """\
List of Python packages to include in the distribution.
Sub-packages are automatically included.
""",
        ),
    },
)

def _py_wheel_impl(ctx):
    outfile = ctx.actions.declare_file("-".join([
        ctx.attr.distribution,
        ctx.attr.version,
        ctx.attr.python_tag,
        ctx.attr.abi,
        ctx.attr.platform,
    ]) + ".whl")

    inputs_to_package = depset(
        direct = ctx.files.deps,
    )

    # Inputs to this rule which are not to be packaged.
    # Currently this is only the description file (if used).
    other_inputs = []

    # Wrap the inputs into a file to reduce command line length.
    packageinputfile = ctx.actions.declare_file(ctx.attr.name + '_target_wrapped_inputs.txt')
    content = ''
    for input_file in inputs_to_package.to_list():
        content += _input_file_to_arg(input_file) + '\n'
    ctx.actions.write(output = packageinputfile, content=content)
    other_inputs.append(packageinputfile)

    args = ctx.actions.args()
    args.add("--name", ctx.attr.distribution)
    args.add("--version", ctx.attr.version)
    args.add("--python_tag", ctx.attr.python_tag)
    args.add("--abi", ctx.attr.abi)
    args.add("--platform", ctx.attr.platform)
    args.add("--out", outfile.path)
    args.add_all(ctx.attr.strip_path_prefixes, format_each = "--strip_path_prefix=%s")

    args.add("--input_file_list", packageinputfile)

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
        args.add("--header", h)

    for c in ctx.attr.classifiers:
        args.add("--classifier", c)

    for r in ctx.attr.requires:
        args.add("--requires", r)

    for option, requirements in ctx.attr.extra_requires.items():
        for r in requirements:
            args.add("--extra_requires", r + ";" + option)

    for name, ref in ctx.attr.console_scripts.items():
        args.add("--console_script", name + " = " + ref)

    if ctx.attr.description_file:
        description_file = ctx.file.description_file
        args.add("--description_file", description_file)
        other_inputs.append(description_file)

    ctx.actions.run(
        inputs = depset(direct = other_inputs, transitive = [inputs_to_package]),
        outputs = [outfile],
        arguments = [args],
        executable = ctx.executable._wheelmaker,
        progress_message = "Building wheel",
    )
    return [DefaultInfo(
        files = depset([outfile]),
        data_runfiles = ctx.runfiles(files = [outfile]),
    )]

def _concat_dicts(*dicts):
    result = {}
    for d in dicts:
        result.update(d)
    return result

_distribution_attrs = {
    "abi": attr.string(
        default = "none",
        doc = "Python ABI tag. 'none' for pure-Python wheels.",
    ),
    "distribution": attr.string(
        mandatory = True,
        doc = """
Name of the distribution.

This should match the project name onm PyPI. It's also the name that is used to
refer to the package in other packages' dependencies.
""",
    ),
    # TODO(pstradomski): Support non-pure wheels
    "platform": attr.string(
        default = "any",
        doc = "Supported platforms. 'any' for pure-Python wheel.",
    ),
    "python_tag": attr.string(
        default = "py3",
        doc = "Supported Python major version. 'py2' or 'py3'",
        values = ["py2", "py3"],
    ),
    "version": attr.string(
        mandatory = True,
        doc = "Version number of the package",
    ),
}

_requirement_attrs = {
    "extra_requires": attr.string_list_dict(
        doc = "List of optional requirements for this package",
    ),
    "requires": attr.string_list(
        doc = "List of requirements for this package",
    ),
}

_entrypoint_attrs = {
    "console_scripts": attr.string_dict(
        doc = """\
console_script entry points, e.g. 'experimental.examples.wheel.main:main'.
""",
    ),
}

_other_attrs = {
    "author": attr.string(default = ""),
    "author_email": attr.string(default = ""),
    "classifiers": attr.string_list(),
    "description_file": attr.label(allow_single_file = True),
    "homepage": attr.string(default = ""),
    "license": attr.string(default = ""),
    "strip_path_prefixes": attr.string_list(
        default = [],
        doc = "path prefixes to strip from files added to the generated package",
    ),
}

py_wheel = rule(
    implementation = _py_wheel_impl,
    doc = """
A rule for building Python Wheels.

Wheels are Python distribution format defined in https://www.python.org/dev/peps/pep-0427/.

This rule packages a set of targets into a single wheel.

Currently only pure-python wheels are supported.

Examples:

<code>
# Package just a specific py_libraries, without their dependencies
py_wheel(
    name = "minimal_with_py_library",
    # Package data. We're building "example_minimal_library-0.0.1-py3-none-any.whl"
    distribution = "example_minimal_library",
    python_tag = "py3",
    version = "0.0.1",
    deps = [
        "//experimental/examples/wheel/lib:module_with_data",
        "//experimental/examples/wheel/lib:simple_module",
    ],
)

# Use py_package to collect all transitive dependencies of a target,
# selecting just the files within a specific python package.
py_package(
    name = "example_pkg",
    # Only include these Python packages.
    packages = ["experimental.examples.wheel"],
    deps = [":main"],
)

py_wheel(
    name = "minimal_with_py_package",
    # Package data. We're building "example_minimal_package-0.0.1-py3-none-any.whl"
    distribution = "example_minimal_package",
    python_tag = "py3",
    version = "0.0.1",
    deps = [":example_pkg"],
)
</code>
""",
    attrs = _concat_dicts(
        {
            "deps": attr.label_list(
                doc = """\
Targets to be included in the distribution.

The targets to package are usually `py_library` rules or filesets (for packaging data files).

Note it's usually better to package `py_library` targets and use
`console_scripts` attribute to specify entry points than to package
`py_binary` rules. `py_binary` targets would wrap a executable script that
tries to locate `.runfiles` directory which is not packaged in the wheel.
""",
            ),
            "_wheelmaker": attr.label(
                executable = True,
                cfg = "host",
                default = "//experimental/rules_python:wheelmaker",
            ),
        },
        _distribution_attrs,
        _requirement_attrs,
        _entrypoint_attrs,
        _other_attrs,
    ),
)
