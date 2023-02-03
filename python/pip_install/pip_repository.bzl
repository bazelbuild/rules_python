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

""

load("//python:repositories.bzl", "get_interpreter_dirname", "is_standalone_interpreter")
load("//python/pip_install:repositories.bzl", "all_requirements")
load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("//python/pip_install/private:srcs.bzl", "PIP_INSTALL_PY_SRCS")

CPPFLAGS = "CPPFLAGS"

COMMAND_LINE_TOOLS_PATH_SLUG = "commandlinetools"

def _construct_pypath(rctx):
    """Helper function to construct a PYTHONPATH.

    Contains entries for code in this repo as well as packages downloaded from //python/pip_install:repositories.bzl.
    This allows us to run python code inside repository rule implementations.

    Args:
        rctx: Handle to the repository_context.
    Returns: String of the PYTHONPATH.
    """

    # Get the root directory of these rules
    rules_root = rctx.path(Label("//:BUILD.bazel")).dirname
    thirdparty_roots = [
        # Includes all the external dependencies from repositories.bzl
        rctx.path(Label("@" + repo + "//:BUILD.bazel")).dirname
        for repo in all_requirements
    ]
    separator = ":" if not "windows" in rctx.os.name.lower() else ";"
    pypath = separator.join([str(p) for p in [rules_root] + thirdparty_roots])
    return pypath

def _get_python_interpreter_attr(rctx):
    """A helper function for getting the `python_interpreter` attribute or it's default

    Args:
        rctx (repository_ctx): Handle to the rule repository context.

    Returns:
        str: The attribute value or it's default
    """
    if rctx.attr.python_interpreter:
        return rctx.attr.python_interpreter

    if "win" in rctx.os.name:
        return "python.exe"
    else:
        return "python3"

def _resolve_python_interpreter(rctx):
    """Helper function to find the python interpreter from the common attributes

    Args:
        rctx: Handle to the rule repository context.
    Returns: Python interpreter path.
    """
    python_interpreter = _get_python_interpreter_attr(rctx)

    if rctx.attr.python_interpreter_target != None:
        target = rctx.attr.python_interpreter_target
        python_interpreter = rctx.path(target)
    elif "/" not in python_interpreter:
        found_python_interpreter = rctx.which(python_interpreter)
        if not found_python_interpreter:
            fail("python interpreter `{}` not found in PATH".format(python_interpreter))
        python_interpreter = found_python_interpreter
    return python_interpreter

def _get_xcode_location_cflags(rctx):
    """Query the xcode sdk location to update cflags

    Figure out if this interpreter target comes from rules_python, and patch the xcode sdk location if so.
    Pip won't be able to compile c extensions from sdists with the pre built python distributions from indygreg
    otherwise. See https://github.com/indygreg/python-build-standalone/issues/103
    """

    # Only run on MacOS hosts
    if not rctx.os.name.lower().startswith("mac os"):
        return []

    # Locate xcode-select
    xcode_select = rctx.which("xcode-select")

    xcode_sdk_location = rctx.execute([xcode_select, "--print-path"])
    if xcode_sdk_location.return_code != 0:
        return []

    xcode_root = xcode_sdk_location.stdout.strip()
    if COMMAND_LINE_TOOLS_PATH_SLUG not in xcode_root.lower():
        # This is a full xcode installation somewhere like /Applications/Xcode13.0.app/Contents/Developer
        # so we need to change the path to to the macos specific tools which are in a different relative
        # path than xcode installed command line tools.
        xcode_root = "{}/Platforms/MacOSX.platform/Developer".format(xcode_root)
    return [
        "-isysroot {}/SDKs/MacOSX.sdk".format(xcode_root),
    ]

def _get_toolchain_unix_cflags(rctx):
    """Gather cflags from a standalone toolchain for unix systems.

    Pip won't be able to compile c extensions from sdists with the pre built python distributions from indygreg
    otherwise. See https://github.com/indygreg/python-build-standalone/issues/103
    """

    # Only run on Unix systems
    if not rctx.os.name.lower().startswith(("mac os", "linux")):
        return []

    # Only update the location when using a standalone toolchain.
    if not is_standalone_interpreter(rctx, rctx.attr.python_interpreter_target):
        return []

    er = rctx.execute([
        rctx.path(rctx.attr.python_interpreter_target).realpath,
        "-c",
        "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')",
    ])
    if er.return_code != 0:
        fail("could not get python version from interpreter (status {}): {}".format(er.return_code, er.stderr))
    _python_version = er.stdout
    include_path = "{}/include/python{}".format(
        get_interpreter_dirname(rctx, rctx.attr.python_interpreter_target),
        _python_version,
    )

    return ["-isystem {}".format(include_path)]

def use_isolated(ctx, attr):
    """Determine whether or not to pass the pip `--isolated` flag to the pip invocation.

    Args:
        ctx: repository or module context
        attr: attributes for the repo rule or tag extension

    Returns:
        True if --isolated should be passed
    """
    use_isolated = attr.isolated

    # The environment variable will take precedence over the attribute
    isolated_env = ctx.os.environ.get("RULES_PYTHON_PIP_ISOLATED", None)
    if isolated_env != None:
        if isolated_env.lower() in ("0", "false"):
            use_isolated = False
        else:
            use_isolated = True

    return use_isolated

def _parse_optional_attrs(rctx, args):
    """Helper function to parse common attributes of pip_repository and whl_library repository rules.

    This function also serializes the structured arguments as JSON
    so they can be passed on the command line to subprocesses.

    Args:
        rctx: Handle to the rule repository context.
        args: A list of parsed args for the rule.
    Returns: Augmented args list.
    """

    if use_isolated(rctx, rctx.attr):
        args.append("--isolated")

    # Check for None so we use empty default types from our attrs.
    # Some args want to be list, and some want to be dict.
    if rctx.attr.extra_pip_args != None:
        args += [
            "--extra_pip_args",
            json.encode(struct(arg = rctx.attr.extra_pip_args)),
        ]

    if rctx.attr.download_only:
        args.append("--download_only")

    if rctx.attr.pip_data_exclude != None:
        args += [
            "--pip_data_exclude",
            json.encode(struct(arg = rctx.attr.pip_data_exclude)),
        ]

    if rctx.attr.enable_implicit_namespace_pkgs:
        args.append("--enable_implicit_namespace_pkgs")

    if rctx.attr.environment != None:
        args += [
            "--environment",
            json.encode(struct(arg = rctx.attr.environment)),
        ]

    return args

def _create_repository_execution_environment(rctx):
    """Create a environment dictionary for processes we spawn with rctx.execute.

    Args:
        rctx: The repository context.
    Returns:
        Dictionary of environment variable suitable to pass to rctx.execute.
    """

    # Gather any available CPPFLAGS values
    cppflags = []
    cppflags.extend(_get_xcode_location_cflags(rctx))
    cppflags.extend(_get_toolchain_unix_cflags(rctx))

    env = {
        "PYTHONPATH": _construct_pypath(rctx),
        CPPFLAGS: " ".join(cppflags),
    }

    return env

_BUILD_FILE_CONTENTS = """\
package(default_visibility = ["//visibility:public"])

# Ensure the `requirements.bzl` source can be accessed by stardoc, since users load() from it
exports_files(["requirements.bzl"])
"""

def locked_requirements_label(ctx, attr):
    """Get the preferred label for a locked requirements file based on platform.

    Args:
        ctx: repository or module context
        attr: attributes for the repo rule or tag extension

    Returns:
        Label
    """
    os = ctx.os.name.lower()
    requirements_txt = attr.requirements_lock
    if os.startswith("mac os") and attr.requirements_darwin != None:
        requirements_txt = attr.requirements_darwin
    elif os.startswith("linux") and attr.requirements_linux != None:
        requirements_txt = attr.requirements_linux
    elif "win" in os and attr.requirements_windows != None:
        requirements_txt = attr.requirements_windows
    if not requirements_txt:
        fail("""\
A requirements_lock attribute must be specified, or a platform-specific lockfile using one of the requirements_* attributes.
""")
    return requirements_txt

# Keep in sync with `_clean_name` in generated requirements.bzl
def _clean_pkg_name(name):
    return name.replace("-", "_").replace(".", "_").lower()

def _bzlmod_pkg_aliases(rctx, requirements_txt):
    """Create alias declarations for each python dependency.

    The aliases should be appended to the pip_parse repo's BUILD.bazel file. These aliases
    allow users to use requirement() without needed a corresponding `use_repo()` for each dep
    when using bzlmod.

    Args:
        rctx: the repository context
        requirements_txt: label to the requirements lock file
    """
    requirements = parse_requirements(rctx.read(requirements_txt)).requirements

    build_content = ""
    for requirement in requirements:
        build_content += """\

alias(
    name = "{name}_pkg",
    actual = "@{repo_prefix}{dep}//:pkg",
)

alias(
    name = "{name}_whl",
    actual = "@{repo_prefix}{dep}//:whl",
)

alias(
    name = "{name}_data",
    actual = "@{repo_prefix}{dep}//:data",
)

alias(
    name = "{name}_dist_info",
    actual = "@{repo_prefix}{dep}//:dist_info",
)
""".format(
            name = _clean_pkg_name(requirement[0]),
            repo_prefix = rctx.attr.repo_prefix,
            dep = _clean_pkg_name(requirement[0]),
        )

    return build_content

def _pip_repository_impl(rctx):
    python_interpreter = _resolve_python_interpreter(rctx)

    # Write the annotations file to pass to the wheel maker
    annotations = {package: json.decode(data) for (package, data) in rctx.attr.annotations.items()}
    annotations_file = rctx.path("annotations.json")
    rctx.file(annotations_file, json.encode_indent(annotations, indent = " " * 4))

    requirements_txt = locked_requirements_label(rctx, rctx.attr)
    args = [
        python_interpreter,
        "-m",
        "python.pip_install.tools.lock_file_generator.lock_file_generator",
        "--requirements_lock",
        rctx.path(requirements_txt),
        "--requirements_lock_label",
        str(requirements_txt),
        # pass quiet and timeout args through to child repos.
        "--quiet",
        str(rctx.attr.quiet),
        "--timeout",
        str(rctx.attr.timeout),
        "--annotations",
        annotations_file,
        "--bzlmod",
        str(rctx.attr.bzlmod).lower(),
    ]

    args += ["--python_interpreter", _get_python_interpreter_attr(rctx)]
    if rctx.attr.python_interpreter_target:
        args += ["--python_interpreter_target", str(rctx.attr.python_interpreter_target)]
    progress_message = "Parsing requirements to starlark"

    args += ["--repo", rctx.attr.name, "--repo-prefix", rctx.attr.repo_prefix]
    args = _parse_optional_attrs(rctx, args)

    rctx.report_progress(progress_message)

    result = rctx.execute(
        args,
        # Manually construct the PYTHONPATH since we cannot use the toolchain here
        environment = _create_repository_execution_environment(rctx),
        timeout = rctx.attr.timeout,
        quiet = rctx.attr.quiet,
    )

    if result.return_code:
        fail("rules_python failed: %s (%s)" % (result.stdout, result.stderr))

    # We need a BUILD file to load the generated requirements.bzl
    build_contents = _BUILD_FILE_CONTENTS

    if rctx.attr.bzlmod:
        build_contents += _bzlmod_pkg_aliases(rctx, requirements_txt)

    rctx.file("BUILD.bazel", build_contents + "\n# The requirements.bzl file was generated by running:\n# " + " ".join([str(a) for a in args]))

    return

common_env = [
    "RULES_PYTHON_PIP_ISOLATED",
]

common_attrs = {
    "download_only": attr.bool(
        doc = """
Whether to use "pip download" instead of "pip wheel". Disables building wheels from source, but allows use of
--platform, --python-version, --implementation, and --abi in --extra_pip_args to download wheels for a different
platform from the host platform.
        """,
    ),
    "enable_implicit_namespace_pkgs": attr.bool(
        default = False,
        doc = """
If true, disables conversion of native namespace packages into pkg-util style namespace packages. When set all py_binary
and py_test targets must specify either `legacy_create_init=False` or the global Bazel option
`--incompatible_default_to_explicit_init_py` to prevent `__init__.py` being automatically generated in every directory.

This option is required to support some packages which cannot handle the conversion to pkg-util style.
            """,
    ),
    "environment": attr.string_dict(
        doc = """
Environment variables to set in the pip subprocess.
Can be used to set common variables such as `http_proxy`, `https_proxy` and `no_proxy`
Note that pip is run with "--isolated" on the CLI so `PIP_<VAR>_<NAME>`
style env vars are ignored, but env vars that control requests and urllib3
can be passed.
        """,
        default = {},
    ),
    "extra_pip_args": attr.string_list(
        doc = "Extra arguments to pass on to pip. Must not contain spaces.",
    ),
    "isolated": attr.bool(
        doc = """\
Whether or not to pass the [--isolated](https://pip.pypa.io/en/stable/cli/pip/#cmdoption-isolated) flag to
the underlying pip command. Alternatively, the `RULES_PYTHON_PIP_ISOLATED` enviornment varaible can be used
to control this flag.
""",
        default = True,
    ),
    "pip_data_exclude": attr.string_list(
        doc = "Additional data exclusion parameters to add to the pip packages BUILD file.",
    ),
    "python_interpreter": attr.string(
        doc = """\
The python interpreter to use. This can either be an absolute path or the name
of a binary found on the host's `PATH` environment variable. If no value is set
`python3` is defaulted for Unix systems and `python.exe` for Windows.
""",
        # NOTE: This attribute should not have a default. See `_get_python_interpreter_attr`
        # default = "python3"
    ),
    "python_interpreter_target": attr.label(
        allow_single_file = True,
        doc = """
If you are using a custom python interpreter built by another repository rule,
use this attribute to specify its BUILD target. This allows pip_repository to invoke
pip using the same interpreter as your toolchain. If set, takes precedence over
python_interpreter.
""",
    ),
    "quiet": attr.bool(
        default = True,
        doc = "If True, suppress printing stdout and stderr output to the terminal.",
    ),
    "repo_prefix": attr.string(
        doc = """
Prefix for the generated packages will be of the form `@<prefix><sanitized-package-name>//...`
""",
    ),
    # 600 is documented as default here: https://docs.bazel.build/versions/master/skylark/lib/repository_ctx.html#execute
    "timeout": attr.int(
        default = 600,
        doc = "Timeout (in seconds) on the rule's execution duration.",
    ),
    "_py_srcs": attr.label_list(
        doc = "Python sources used in the repository rule",
        allow_files = True,
        default = PIP_INSTALL_PY_SRCS,
    ),
}

pip_repository_attrs = {
    "annotations": attr.string_dict(
        doc = "Optional annotations to apply to packages",
    ),
    "bzlmod": attr.bool(
        default = False,
        doc = """Whether this repository rule is invoked under bzlmod, in which case
we do not create the install_deps() macro.
""",
    ),
    "requirements_darwin": attr.label(
        allow_single_file = True,
        doc = "Override the requirements_lock attribute when the host platform is Mac OS",
    ),
    "requirements_linux": attr.label(
        allow_single_file = True,
        doc = "Override the requirements_lock attribute when the host platform is Linux",
    ),
    "requirements_lock": attr.label(
        allow_single_file = True,
        doc = """
A fully resolved 'requirements.txt' pip requirement file containing the transitive set of your dependencies. If this file is passed instead
of 'requirements' no resolve will take place and pip_repository will create individual repositories for each of your dependencies so that
wheels are fetched/built only for the targets specified by 'build/run/test'.
""",
    ),
    "requirements_windows": attr.label(
        allow_single_file = True,
        doc = "Override the requirements_lock attribute when the host platform is Windows",
    ),
}

pip_repository_attrs.update(**common_attrs)

pip_repository = repository_rule(
    attrs = pip_repository_attrs,
    doc = """A rule for importing `requirements.txt` dependencies into Bazel.

This rule imports a `requirements.txt` file and generates a new
`requirements.bzl` file.  This is used via the `WORKSPACE` pattern:

```python
pip_repository(
    name = "foo",
    requirements = ":requirements.txt",
)
```

You can then reference imported dependencies from your `BUILD` file with:

```python
load("@foo//:requirements.bzl", "requirement")
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

Or alternatively:
```python
load("@foo//:requirements.bzl", "all_requirements")
py_binary(
    name = "baz",
    ...
    deps = [
       ":foo",
    ] + all_requirements,
)
```
""",
    implementation = _pip_repository_impl,
    environ = common_env,
)

def _whl_library_impl(rctx):
    python_interpreter = _resolve_python_interpreter(rctx)

    args = [
        python_interpreter,
        "-m",
        "python.pip_install.tools.wheel_installer.wheel_installer",
        "--requirement",
        rctx.attr.requirement,
        "--repo",
        rctx.attr.repo,
        "--repo-prefix",
        rctx.attr.repo_prefix,
    ]
    if rctx.attr.annotation:
        args.extend([
            "--annotation",
            rctx.path(rctx.attr.annotation),
        ])

    args = _parse_optional_attrs(rctx, args)

    result = rctx.execute(
        args,
        # Manually construct the PYTHONPATH since we cannot use the toolchain here
        environment = _create_repository_execution_environment(rctx),
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.timeout,
    )

    if result.return_code:
        fail("whl_library %s failed: %s (%s)" % (rctx.attr.name, result.stdout, result.stderr))

    return

whl_library_attrs = {
    "annotation": attr.label(
        doc = (
            "Optional json encoded file containing annotation to apply to the extracted wheel. " +
            "See `package_annotation`"
        ),
        allow_files = True,
    ),
    "repo": attr.string(
        mandatory = True,
        doc = "Pointer to parent repo name. Used to make these rules rerun if the parent repo changes.",
    ),
    "requirement": attr.string(
        mandatory = True,
        doc = "Python requirement string describing the package to make available",
    ),
}

whl_library_attrs.update(**common_attrs)

whl_library = repository_rule(
    attrs = whl_library_attrs,
    doc = """
Download and extracts a single wheel based into a bazel repo based on the requirement string passed in.
Instantiated from pip_repository and inherits config options from there.""",
    implementation = _whl_library_impl,
    environ = common_env,
)

def package_annotation(
        additive_build_content = None,
        copy_files = {},
        copy_executables = {},
        data = [],
        data_exclude_glob = [],
        srcs_exclude_glob = []):
    """Annotations to apply to the BUILD file content from package generated from a `pip_repository` rule.

    [cf]: https://github.com/bazelbuild/bazel-skylib/blob/main/docs/copy_file_doc.md

    Args:
        additive_build_content (str, optional): Raw text to add to the generated `BUILD` file of a package.
        copy_files (dict, optional): A mapping of `src` and `out` files for [@bazel_skylib//rules:copy_file.bzl][cf]
        copy_executables (dict, optional): A mapping of `src` and `out` files for
            [@bazel_skylib//rules:copy_file.bzl][cf]. Targets generated here will also be flagged as
            executable.
        data (list, optional): A list of labels to add as `data` dependencies to the generated `py_library` target.
        data_exclude_glob (list, optional): A list of exclude glob patterns to add as `data` to the generated
            `py_library` target.
        srcs_exclude_glob (list, optional): A list of labels to add as `srcs` to the generated `py_library` target.

    Returns:
        str: A json encoded string of the provided content.
    """
    return json.encode(struct(
        additive_build_content = additive_build_content,
        copy_files = copy_files,
        copy_executables = copy_executables,
        data = data,
        data_exclude_glob = data_exclude_glob,
        srcs_exclude_glob = srcs_exclude_glob,
    ))
