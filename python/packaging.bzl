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

WheelInfo = provider("Provides info about python wheels.", fields = [
    "abi",
    "distribution",
    "platform",
    "python_tag",
    "version_file",
    "wheel_file",
])

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
    version_file = ctx.actions.declare_file(ctx.label.name + "_version.txt")
    version_args = ctx.actions.args()
    version_args.add("--version", ctx.attr.version)
    version_args.add("--bazel_info_file", ctx.info_file)
    version_args.add("--bazel_version_file", ctx.version_file)
    version_args.add("--out", version_file.path)

    ctx.actions.run(
        inputs = depset([ctx.info_file, ctx.version_file]),
        outputs = [version_file],
        arguments = [version_args],
        executable = ctx.executable._wheelversioner,
        progress_message = "Versioning wheel",
    )

    wheel_file = ctx.actions.declare_file(ctx.label.name + ".whl")

    inputs_to_package = depset(
        direct = ctx.files.deps,
    )

    # Inputs to this rule which are not to be packaged.
    # Currently this is only the description file (if used).
    other_inputs = []

    # Wrap the inputs into a file to reduce command line length.
    packageinputfile = ctx.actions.declare_file(ctx.attr.name + "_target_wrapped_inputs.txt")
    content = ""
    for input_file in inputs_to_package.to_list():
        content += _input_file_to_arg(input_file) + "\n"
    ctx.actions.write(output = packageinputfile, content = content)
    other_inputs.append(packageinputfile)

    args = ctx.actions.args()
    args.add("--name", ctx.attr.distribution)
    args.add("--version_file", version_file.path)
    args.add("--python_tag", ctx.attr.python_tag)
    args.add("--python_requires", ctx.attr.python_requires)
    args.add("--abi", ctx.attr.abi)
    args.add("--platform", ctx.attr.platform)
    args.add("--out", wheel_file.path)
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

    # Merge console_scripts into entry_points.
    entrypoints = dict(ctx.attr.entry_points)  # Copy so we can mutate it
    if ctx.attr.console_scripts:
        # Copy a console_scripts group that may already exist, so we can mutate it.
        console_scripts = list(entrypoints.get("console_scripts", []))
        entrypoints["console_scripts"] = console_scripts
        for name, ref in ctx.attr.console_scripts.items():
            console_scripts.append("{name} = {ref}".format(name = name, ref = ref))

    # If any entry_points are provided, construct the file here and add it to the files to be packaged.
    # see: https://packaging.python.org/specifications/entry-points/
    if entrypoints:
        lines = []
        for group, entries in sorted(entrypoints.items()):
            if lines:
                # Blank line between groups
                lines.append("")
            lines.append("[{group}]".format(group = group))
            lines += sorted(entries)
        entry_points_file = ctx.actions.declare_file(ctx.attr.name + "_entry_points.txt")
        content = "\n".join(lines)
        ctx.actions.write(output = entry_points_file, content = content)
        other_inputs.append(entry_points_file)
        args.add("--entry_points_file", entry_points_file)

    if ctx.attr.description_file:
        description_file = ctx.file.description_file
        args.add("--description_file", description_file)
        other_inputs.append(description_file)

    ctx.actions.run(
        inputs = depset(
            direct = other_inputs + [version_file],
            transitive = [inputs_to_package]
        ),
        outputs = [wheel_file],
        arguments = [args],
        executable = ctx.executable._wheelmaker,
        progress_message = "Building wheel",
    )
    return [
        WheelInfo(
            distribution = ctx.attr.distribution,
            python_tag = ctx.attr.python_tag,
            abi = ctx.attr.abi,
            platform = ctx.attr.platform,
            wheel_file = wheel_file,
            version_file = version_file,
        ),
        DefaultInfo(
            files = depset([wheel_file, version_file]),
            data_runfiles = ctx.runfiles(files = [wheel_file, version_file]),
        )
    ]

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
    "platform": attr.string(
        default = "any",
        doc = """\
Supported platform. Use 'any' for pure-Python wheel.

If you have included platform-specific data, such as a .pyd or .so
extension module, you will need to specify the platform in standard
pip format. If you support multiple platforms, you can define
platform constraints, then use a select() to specify the appropriate
specifier, eg:

    platform = select({
        "//platforms:windows_x86_64": "win_amd64",
        "//platforms:macos_x86_64": "macosx_10_7_x86_64",
        "//platforms:linux_x86_64": "manylinux2014_x86_64",
    })
""",
    ),
    "python_tag": attr.string(
        default = "py3",
        doc = "Supported Python version(s), eg 'py3', 'cp35.cp36', etc",
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
Deprecated console_script entry points, e.g. {'main': 'examples.wheel.main:main'}.

Deprecated: prefer the `entry_points` attribute, which supports `console_scripts` as well as other entry points.
""",
    ),
    "entry_points": attr.string_list_dict(
        doc = """\
entry_points, e.g. {'console_scripts': ['main = examples.wheel.main:main']}.
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
    "python_requires": attr.string(default = ""),
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
        "//examples/wheel/lib:module_with_data",
        "//examples/wheel/lib:simple_module",
    ],
)

# Use py_package to collect all transitive dependencies of a target,
# selecting just the files within a specific python package.
py_package(
    name = "example_pkg",
    # Only include these Python packages.
    packages = ["examples.wheel"],
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
`entry_points` attribute to specify `console_scripts` than to package
`py_binary` rules. `py_binary` targets would wrap a executable script that
tries to locate `.runfiles` directory which is not packaged in the wheel.
""",
            ),
            "_wheelmaker": attr.label(
                executable = True,
                cfg = "host",
                default = "//tools:wheelmaker",
            ),
            "_wheelversioner": attr.label(
                executable = True,
                cfg = "host",
                default = "//tools:wheelversioner",
            ),
        },
        _distribution_attrs,
        _requirement_attrs,
        _entrypoint_attrs,
        _other_attrs,
    ),
)

def _py_wheel_push_impl(ctx):
    wheel_info = ctx.attr.wheel[WheelInfo]

    wheel_file = wheel_info.wheel_file
    version_file = wheel_info.version_file

    pusher_args = [
        "--distribution", wheel_info.distribution,
        "--python_tag", wheel_info.python_tag,
        "--abi", wheel_info.abi,
        "--platform", wheel_info.platform,
        "--wheel_file", wheel_file.short_path,
        "--version_file", version_file.short_path,
    ]
    if ctx.attr.repository:
        pusher_args.extend(["--repository", ctx.attr.repository])
    if ctx.attr.repository_url:
        pusher_args.extend(["--repository_url", ctx.attr.repository_url])
    if ctx.attr.non_interactive:
        pusher_args.append("--non_interactive")
    if ctx.attr.skip_existing:
        pusher_args.append("--skip_existing")
    if ctx.attr.verbose:
        pusher_args.append("--verbose")

    pusher_runfiles = [ctx.executable._wheelpusher, wheel_file, version_file]
    runfiles = ctx.runfiles(files = pusher_runfiles)
    runfiles = runfiles.merge(ctx.attr._wheelpusher[DefaultInfo].default_runfiles)

    exe = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._push_wheel_sh_tpl,
        output = exe,
        substitutions = {
            "%{args}": " ".join(pusher_args),
            "%{cmd}": ctx.executable._wheelpusher.short_path,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = exe,
            runfiles = runfiles,
        ),
    ]


py_wheel_push = rule(
    implementation = _py_wheel_push_impl,
    doc  = "Pushes a Python wheel.",
    attrs = {
        "wheel": attr.label(
            mandatory = True,
            doc = "The wheel to be pushed.",
            providers = [WheelInfo],
        ),
        "repository": attr.string(),
        "repository_url": attr.string(),
        "non_interactive": attr.bool(default=True),
        "skip_existing": attr.bool(default=True),
        "verbose": attr.bool(default=False),
        "_wheelpusher": attr.label(
            executable = True,
            cfg = "host",
            default = "//tools:wheelpusher",
        ),
        "_push_wheel_sh_tpl": attr.label(
            doc = "The script template to use.",
            allow_single_file = True,
            default = "//tools:push_wheel.sh.tpl",
        ),
    },
    executable = True,
)
