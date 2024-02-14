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

load("@bazel_skylib//lib:sets.bzl", "sets")
load("//python:repositories.bzl", "is_standalone_interpreter")
load("//python:versions.bzl", "WINDOWS_NAME")
load("//python/pip_install:repositories.bzl", "all_requirements")
load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("//python/pip_install/private:generate_group_library_build_bazel.bzl", "generate_group_library_build_bazel")
load("//python/pip_install/private:generate_whl_library_build_bazel.bzl", "generate_whl_library_build_bazel")
load("//python/pip_install/private:srcs.bzl", "PIP_INSTALL_PY_SRCS")
load("//python/private:envsubst.bzl", "envsubst")
load("//python/private:normalize_name.bzl", "normalize_name")
load("//python/private:parse_whl_name.bzl", "parse_whl_name")
load("//python/private:patch_whl.bzl", "patch_whl")
load("//python/private:render_pkg_aliases.bzl", "render_pkg_aliases", "whl_alias")
load("//python/private:repo_utils.bzl", "REPO_DEBUG_ENV_VAR", "repo_utils")
load("//python/private:toolchains_repo.bzl", "get_host_os_arch")
load("//python/private:whl_target_platforms.bzl", "whl_target_platforms")

CPPFLAGS = "CPPFLAGS"

COMMAND_LINE_TOOLS_PATH_SLUG = "commandlinetools"

_WHEEL_ENTRY_POINT_PREFIX = "rules_python_wheel_entry_point"

def _construct_pypath(rctx):
    """Helper function to construct a PYTHONPATH.

    Contains entries for code in this repo as well as packages downloaded from //python/pip_install:repositories.bzl.
    This allows us to run python code inside repository rule implementations.

    Args:
        rctx: Handle to the repository_context.

    Returns: String of the PYTHONPATH.
    """

    separator = ":" if not "windows" in rctx.os.name.lower() else ";"
    pypath = separator.join([
        str(rctx.path(entry).dirname)
        for entry in rctx.attr._python_path_entries
    ])
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

    Returns:
        `path` object, for the resolved path to the Python interpreter.
    """
    python_interpreter = _get_python_interpreter_attr(rctx)

    if rctx.attr.python_interpreter_target != None:
        python_interpreter = rctx.path(rctx.attr.python_interpreter_target)

        (os, _) = get_host_os_arch(rctx)

        # On Windows, the symlink doesn't work because Windows attempts to find
        # Python DLLs where the symlink is, not where the symlink points.
        if os == WINDOWS_NAME:
            python_interpreter = python_interpreter.realpath
    elif "/" not in python_interpreter:
        # It's a plain command, e.g. "python3", to look up in the environment.
        found_python_interpreter = rctx.which(python_interpreter)
        if not found_python_interpreter:
            fail("python interpreter `{}` not found in PATH".format(python_interpreter))
        python_interpreter = found_python_interpreter
    else:
        python_interpreter = rctx.path(python_interpreter)
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

    xcode_sdk_location = repo_utils.execute_unchecked(
        rctx,
        op = "GetXcodeLocation",
        arguments = [repo_utils.which_checked(rctx, "xcode-select"), "--print-path"],
    )
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

def _get_toolchain_unix_cflags(rctx, python_interpreter):
    """Gather cflags from a standalone toolchain for unix systems.

    Pip won't be able to compile c extensions from sdists with the pre built python distributions from indygreg
    otherwise. See https://github.com/indygreg/python-build-standalone/issues/103
    """

    # Only run on Unix systems
    if not rctx.os.name.lower().startswith(("mac os", "linux")):
        return []

    # Only update the location when using a standalone toolchain.
    if not is_standalone_interpreter(rctx, python_interpreter):
        return []

    stdout = repo_utils.execute_checked_stdout(
        rctx,
        op = "GetPythonVersionForUnixCflags",
        arguments = [
            python_interpreter,
            "-c",
            "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}', end='')",
        ],
    )
    _python_version = stdout
    include_path = "{}/include/python{}".format(
        python_interpreter.dirname,
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

    # At the time of writing, the very latest Bazel, as in `USE_BAZEL_VERSION=last_green bazelisk`
    # supports rctx.getenv(name, default): When building incrementally, any change to the value of
    # the variable named by name will cause this repository to be re-fetched. That hasn't yet made
    # its way into the official releases, though.
    if "getenv" in dir(rctx):
        getenv = rctx.getenv
    else:
        getenv = rctx.os.environ.get

    # Check for None so we use empty default types from our attrs.
    # Some args want to be list, and some want to be dict.
    if rctx.attr.extra_pip_args != None:
        args += [
            "--extra_pip_args",
            json.encode(struct(arg = [
                envsubst(pip_arg, rctx.attr.envsubst, getenv)
                for pip_arg in rctx.attr.extra_pip_args
            ])),
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

def _create_repository_execution_environment(rctx, python_interpreter):
    """Create a environment dictionary for processes we spawn with rctx.execute.

    Args:
        rctx (repository_ctx): The repository context.
        python_interpreter (path): The resolved python interpreter.
    Returns:
        Dictionary of environment variable suitable to pass to rctx.execute.
    """

    # Gather any available CPPFLAGS values
    cppflags = []
    cppflags.extend(_get_xcode_location_cflags(rctx))
    cppflags.extend(_get_toolchain_unix_cflags(rctx, python_interpreter))

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

def _pip_repository_impl(rctx):
    requirements_txt = locked_requirements_label(rctx, rctx.attr)
    content = rctx.read(requirements_txt)
    parsed_requirements_txt = parse_requirements(content)

    packages = [(normalize_name(name), requirement) for name, requirement in parsed_requirements_txt.requirements]

    bzl_packages = sorted([normalize_name(name) for name, _ in parsed_requirements_txt.requirements])

    # Normalize cycles first
    requirement_cycles = {
        name: sorted(sets.to_list(sets.make(deps)))
        for name, deps in rctx.attr.experimental_requirement_cycles.items()
    }

    # Check for conflicts between cycles _before_ we normalize package names so
    # that reported errors use the names the user specified
    for i in range(len(requirement_cycles)):
        left_group = requirement_cycles.keys()[i]
        left_deps = requirement_cycles.values()[i]
        for j in range(len(requirement_cycles) - (i + 1)):
            right_deps = requirement_cycles.values()[1 + i + j]
            right_group = requirement_cycles.keys()[1 + i + j]
            for d in left_deps:
                if d in right_deps:
                    fail("Error: Requirement %s cannot be repeated between cycles %s and %s; please merge the cycles." % (d, left_group, right_group))

    # And normalize the names as used in the cycle specs
    #
    # NOTE: We must check that a listed dependency is actually in the actual
    # requirements set for the current platform so that we can support cycles in
    # platform-conditional requirements. Otherwise we'll blindly generate a
    # label referencing a package which may not be installed on the current
    # platform.
    requirement_cycles = {
        normalize_name(name): sorted([normalize_name(d) for d in group if normalize_name(d) in bzl_packages])
        for name, group in requirement_cycles.items()
    }

    imports = [
        # NOTE: Maintain the order consistent with `buildifier`
        'load("@rules_python//python:pip.bzl", "pip_utils")',
        'load("@rules_python//python/pip_install:pip_repository.bzl", "group_library", "whl_library")',
    ]

    annotations = {}
    for pkg, annotation in rctx.attr.annotations.items():
        filename = "{}.annotation.json".format(normalize_name(pkg))
        rctx.file(filename, json.encode_indent(json.decode(annotation)))
        annotations[pkg] = "@{name}//:{filename}".format(name = rctx.attr.name, filename = filename)

    tokenized_options = []
    for opt in parsed_requirements_txt.options:
        for p in opt.split(" "):
            tokenized_options.append(p)

    options = tokenized_options + rctx.attr.extra_pip_args

    config = {
        "download_only": rctx.attr.download_only,
        "enable_implicit_namespace_pkgs": rctx.attr.enable_implicit_namespace_pkgs,
        "environment": rctx.attr.environment,
        "envsubst": rctx.attr.envsubst,
        "extra_pip_args": options,
        "isolated": use_isolated(rctx, rctx.attr),
        "pip_data_exclude": rctx.attr.pip_data_exclude,
        "python_interpreter": _get_python_interpreter_attr(rctx),
        "quiet": rctx.attr.quiet,
        "repo": rctx.attr.name,
        "repo_prefix": "{}_".format(rctx.attr.name),
        "timeout": rctx.attr.timeout,
    }

    if rctx.attr.python_interpreter_target:
        config["python_interpreter_target"] = str(rctx.attr.python_interpreter_target)
    if rctx.attr.experimental_target_platforms:
        config["experimental_target_platforms"] = rctx.attr.experimental_target_platforms

    macro_tmpl = "@%s//{}:{}" % rctx.attr.name

    aliases = render_pkg_aliases(
        aliases = {
            pkg: [whl_alias(repo = rctx.attr.name + "_" + pkg)]
            for pkg in bzl_packages or []
        },
    )
    for path, contents in aliases.items():
        rctx.file(path, contents)

    rctx.file("BUILD.bazel", _BUILD_FILE_CONTENTS)
    rctx.template("requirements.bzl", rctx.attr._template, substitutions = {
        "%%ALL_DATA_REQUIREMENTS%%": _format_repr_list([
            macro_tmpl.format(p, "data")
            for p in bzl_packages
        ]),
        "%%ALL_REQUIREMENTS%%": _format_repr_list([
            macro_tmpl.format(p, "pkg")
            for p in bzl_packages
        ]),
        "%%ALL_REQUIREMENT_GROUPS%%": _format_dict(_repr_dict(requirement_cycles)),
        "%%ALL_WHL_REQUIREMENTS_BY_PACKAGE%%": _format_dict(_repr_dict({
            p: macro_tmpl.format(p, "whl")
            for p in bzl_packages
        })),
        "%%ANNOTATIONS%%": _format_dict(_repr_dict(annotations)),
        "%%CONFIG%%": _format_dict(_repr_dict(config)),
        "%%EXTRA_PIP_ARGS%%": json.encode(options),
        "%%IMPORTS%%": "\n".join(imports),
        "%%MACRO_TMPL%%": macro_tmpl,
        "%%NAME%%": rctx.attr.name,
        "%%PACKAGES%%": _format_repr_list(
            [
                ("{}_{}".format(rctx.attr.name, p), r)
                for p, r in packages
            ],
        ),
        "%%REQUIREMENTS_LOCK%%": str(requirements_txt),
    })

    return

common_env = [
    "RULES_PYTHON_PIP_ISOLATED",
    REPO_DEBUG_ENV_VAR,
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
can be passed. If you need `PIP_<VAR>_<NAME>`, take a look at `extra_pip_args`
and `envsubst`.
        """,
        default = {},
    ),
    "envsubst": attr.string_list(
        mandatory = False,
        doc = """\
A list of environment variables to substitute (e.g. `["PIP_INDEX_URL",
"PIP_RETRIES"]`). The corresponding variables are expanded in `extra_pip_args`
using the syntax `$VARNAME` or `${VARNAME}` (expanding to empty string if unset)
or `${VARNAME:-default}` (expanding to default if the variable is unset or empty
in the environment). Note: On Bazel 6 and Bazel 7 changes to the variables named
here do not cause packages to be re-fetched. Don't fetch different things based
on the value of these variables.
""",
    ),
    "experimental_requirement_cycles": attr.string_list_dict(
        default = {},
        doc = """\
A mapping of dependency cycle names to a list of requirements which form that cycle.

Requirements which form cycles will be installed together and taken as
dependencies together in order to ensure that the cycle is always satisified.

Example:
  `sphinx` depends on `sphinxcontrib-serializinghtml`
  When listing both as requirements, ala

  ```
  py_binary(
    name = "doctool",
    ...
    deps = [
      "@pypi//sphinx:pkg",
      "@pypi//sphinxcontrib_serializinghtml",
     ]
  )
  ```

  Will produce a Bazel error such as

  ```
  ERROR: .../external/pypi_sphinxcontrib_serializinghtml/BUILD.bazel:44:6: in alias rule @pypi_sphinxcontrib_serializinghtml//:pkg: cycle in dependency graph:
      //:doctool (...)
      @pypi//sphinxcontrib_serializinghtml:pkg (...)
  .-> @pypi_sphinxcontrib_serializinghtml//:pkg (...)
  |   @pypi_sphinxcontrib_serializinghtml//:_pkg (...)
  |   @pypi_sphinx//:pkg (...)
  |   @pypi_sphinx//:_pkg (...)
  `-- @pypi_sphinxcontrib_serializinghtml//:pkg (...)
  ```

  Which we can resolve by configuring these two requirements to be installed together as a cycle

  ```
  pip_parse(
    ...
    experimental_requirement_cycles = {
      "sphinx": [
        "sphinx",
        "sphinxcontrib-serializinghtml",
      ]
    },
  )
  ```

Warning:
  If a dependency participates in multiple cycles, all of those cycles must be
  collapsed down to one. For instance `a <-> b` and `a <-> c` cannot be listed
  as two separate cycles.
""",
    ),
    "experimental_target_platforms": attr.string_list(
        default = [],
        doc = """\
A list of platforms that we will generate the conditional dependency graph for
cross platform wheels by parsing the wheel metadata. This will generate the
correct dependencies for packages like `sphinx` or `pylint`, which include
`colorama` when installed and used on Windows platforms.

An empty list means falling back to the legacy behaviour where the host
platform is the target platform.

WARNING: It may not work as expected in cases where the python interpreter
implementation that is being used at runtime is different between different platforms.
This has been tested for CPython only.

For specific target platforms use values of the form `<os>_<arch>` where `<os>`
is one of `linux`, `osx`, `windows` and arch is one of `x86_64`, `x86_32`,
`aarch64`, `s390x` and `ppc64le`.

You can also target a specific Python version by using `cp3<minor_version>_<os>_<arch>`.
If multiple python versions are specified as target platforms, then select statements
of the `lib` and `whl` targets will include usage of version aware toolchain config
settings like `@rules_python//python/config_settings:is_python_3.y`.

Special values: `host` (for generating deps for the host platform only) and
`<prefix>_*` values. For example, `cp39_*`, `linux_*`, `cp39_linux_*`.

NOTE: this is not for cross-compiling Python wheels but rather for parsing the `whl` METADATA correctly.
""",
    ),
    "extra_pip_args": attr.string_list(
        doc = """Extra arguments to pass on to pip. Must not contain spaces.

Supports environment variables using the syntax `$VARNAME` or
`${VARNAME}` (expanding to empty string if unset) or
`${VARNAME:-default}` (expanding to default if the variable is unset
or empty in the environment), if `"VARNAME"` is listed in the
`envsubst` attribute. See also `envsubst`.
""",
    ),
    "isolated": attr.bool(
        doc = """\
Whether or not to pass the [--isolated](https://pip.pypa.io/en/stable/cli/pip/#cmdoption-isolated) flag to
the underlying pip command. Alternatively, the `RULES_PYTHON_PIP_ISOLATED` environment variable can be used
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
python_interpreter. An example value: "@python3_x86_64-unknown-linux-gnu//:python".
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
        doc = """\
A fully resolved 'requirements.txt' pip requirement file containing the
transitive set of your dependencies. If this file is passed instead of
'requirements' no resolve will take place and pip_repository will create
individual repositories for each of your dependencies so that wheels are
fetched/built only for the targets specified by 'build/run/test'. Note that if
your lockfile is platform-dependent, you can use the `requirements_[platform]`
attributes.
""",
    ),
    "requirements_windows": attr.label(
        allow_single_file = True,
        doc = "Override the requirements_lock attribute when the host platform is Windows",
    ),
    "_template": attr.label(
        default = ":pip_repository_requirements.bzl.tmpl",
    ),
}

pip_repository_attrs.update(**common_attrs)

pip_repository = repository_rule(
    attrs = pip_repository_attrs,
    doc = """Accepts a locked/compiled requirements file and installs the dependencies listed within.

Those dependencies become available in a generated `requirements.bzl` file.
You can instead check this `requirements.bzl` file into your repo, see the "vendoring" section below.

In your WORKSPACE file:

```starlark
load("@rules_python//python:pip.bzl", "pip_parse")

pip_parse(
    name = "pypi",
    requirements_lock = ":requirements.txt",
)

load("@pypi//:requirements.bzl", "install_deps")

install_deps()
```

You can then reference installed dependencies from a `BUILD` file with the alias targets generated in the same repo, for example, for `PyYAML` we would have the following:
- `@pypi//pyyaml` and `@pypi//pyyaml:pkg` both point to the `py_library`
  created after extracting the `PyYAML` package.
- `@pypi//pyyaml:data` points to the extra data included in the package.
- `@pypi//pyyaml:dist_info` points to the `dist-info` files in the package.
- `@pypi//pyyaml:whl` points to the wheel file that was extracted.

```starlark
py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       "@pypi//numpy",
       "@pypi//requests",
    ],
)
```

or

```starlark
load("@pypi//:requirements.bzl", "requirement")

py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       requirement("numpy"),
       requirement("requests"),
    ],
)
```

In addition to the `requirement` macro, which is used to access the generated `py_library`
target generated from a package's wheel, The generated `requirements.bzl` file contains
functionality for exposing [entry points][whl_ep] as `py_binary` targets as well.

[whl_ep]: https://packaging.python.org/specifications/entry-points/

```starlark
load("@pypi//:requirements.bzl", "entry_point")

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

```starlark
load("@pip//:requirements.bzl", "entry_point")

alias(
    name = "flake8",
    actual = entry_point("flake8"),
)
```

### Vendoring the requirements.bzl file

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
    ]

    args = _parse_optional_attrs(rctx, args)

    # Manually construct the PYTHONPATH since we cannot use the toolchain here
    environment = _create_repository_execution_environment(rctx, python_interpreter)

    repo_utils.execute_checked(
        rctx,
        op = "whl_library.ResolveRequirement({}, {})".format(rctx.attr.name, rctx.attr.requirement),
        arguments = args,
        environment = environment,
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.timeout,
    )

    whl_path = rctx.path(json.decode(rctx.read("whl_file.json"))["whl_file"])
    if not rctx.delete("whl_file.json"):
        fail("failed to delete the whl_file.json file")

    if rctx.attr.whl_patches:
        patches = {}
        for patch_file, json_args in rctx.attr.whl_patches.items():
            patch_dst = struct(**json.decode(json_args))
            if whl_path.basename in patch_dst.whls:
                patches[patch_file] = patch_dst.patch_strip

        whl_path = patch_whl(
            rctx,
            python_interpreter = python_interpreter,
            whl_path = whl_path,
            patches = patches,
            quiet = rctx.attr.quiet,
            timeout = rctx.attr.timeout,
        )

    target_platforms = rctx.attr.experimental_target_platforms
    if target_platforms:
        parsed_whl = parse_whl_name(whl_path.basename)
        if parsed_whl.platform_tag != "any":
            # NOTE @aignas 2023-12-04: if the wheel is a platform specific
            # wheel, we only include deps for that target platform
            target_platforms = [
                "{}_{}_{}".format(parsed_whl.abi_tag, p.os, p.cpu)
                for p in whl_target_platforms(parsed_whl.platform_tag)
            ]

    repo_utils.execute_checked(
        rctx,
        op = "whl_library.ExtractWheel({}, {})".format(rctx.attr.name, whl_path),
        arguments = args + [
            "--whl-file",
            whl_path,
        ] + ["--platform={}".format(p) for p in target_platforms],
        environment = environment,
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.timeout,
    )

    metadata = json.decode(rctx.read("metadata.json"))
    rctx.delete("metadata.json")

    entry_points = {}
    for item in metadata["entry_points"]:
        name = item["name"]
        module = item["module"]
        attribute = item["attribute"]

        # There is an extreme edge-case with entry_points that end with `.py`
        # See: https://github.com/bazelbuild/bazel/blob/09c621e4cf5b968f4c6cdf905ab142d5961f9ddc/src/test/java/com/google/devtools/build/lib/rules/python/PyBinaryConfiguredTargetTest.java#L174
        entry_point_without_py = name[:-3] + "_py" if name.endswith(".py") else name
        entry_point_target_name = (
            _WHEEL_ENTRY_POINT_PREFIX + "_" + entry_point_without_py
        )
        entry_point_script_name = entry_point_target_name + ".py"

        rctx.file(
            entry_point_script_name,
            _generate_entry_point_contents(module, attribute),
        )
        entry_points[entry_point_without_py] = entry_point_script_name

    build_file_contents = generate_whl_library_build_bazel(
        repo_prefix = rctx.attr.repo_prefix,
        whl_name = whl_path.basename,
        dependencies = metadata["deps"],
        dependencies_by_platform = metadata["deps_by_platform"],
        group_name = rctx.attr.group_name,
        group_deps = rctx.attr.group_deps,
        data_exclude = rctx.attr.pip_data_exclude,
        tags = [
            "pypi_name=" + metadata["name"],
            "pypi_version=" + metadata["version"],
        ],
        entry_points = entry_points,
        annotation = None if not rctx.attr.annotation else struct(**json.decode(rctx.read(rctx.attr.annotation))),
    )
    rctx.file("BUILD.bazel", build_file_contents)

    return

def _generate_entry_point_contents(
        module,
        attribute,
        shebang = "#!/usr/bin/env python3"):
    """Generate the contents of an entry point script.

    Args:
        module (str): The name of the module to use.
        attribute (str): The name of the attribute to call.
        shebang (str, optional): The shebang to use for the entry point python
            file.

    Returns:
        str: A string of python code.
    """
    contents = """\
{shebang}
import sys
from {module} import {attribute}
if __name__ == "__main__":
    sys.exit({attribute}())
""".format(
        shebang = shebang,
        module = module,
        attribute = attribute,
    )
    return contents

whl_library_attrs = {
    "annotation": attr.label(
        doc = (
            "Optional json encoded file containing annotation to apply to the extracted wheel. " +
            "See `package_annotation`"
        ),
        allow_files = True,
    ),
    "group_deps": attr.string_list(
        doc = "List of dependencies to skip in order to break the cycles within a dependency group.",
        default = [],
    ),
    "group_name": attr.string(
        doc = "Name of the group, if any.",
    ),
    "repo": attr.string(
        mandatory = True,
        doc = "Pointer to parent repo name. Used to make these rules rerun if the parent repo changes.",
    ),
    "requirement": attr.string(
        mandatory = True,
        doc = "Python requirement string describing the package to make available",
    ),
    "whl_patches": attr.label_keyed_string_dict(
        doc = """a label-keyed-string dict that has
            json.encode(struct([whl_file], patch_strip]) as values. This
            is to maintain flexibility and correct bzlmod extension interface
            until we have a better way to define whl_library and move whl
            patching to a separate place. INTERNAL USE ONLY.""",
    ),
    "_python_path_entries": attr.label_list(
        # Get the root directory of these rules and keep them as a default attribute
        # in order to avoid unnecessary repository fetching restarts.
        #
        # This is very similar to what was done in https://github.com/bazelbuild/rules_go/pull/3478
        default = [
            Label("//:BUILD.bazel"),
        ] + [
            # Includes all the external dependencies from repositories.bzl
            Label("@" + repo + "//:BUILD.bazel")
            for repo in all_requirements
        ],
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

def _group_library_impl(rctx):
    build_file_contents = generate_group_library_build_bazel(
        repo_prefix = rctx.attr.repo_prefix,
        groups = rctx.attr.groups,
    )
    rctx.file("BUILD.bazel", build_file_contents)

group_library = repository_rule(
    attrs = {
        "groups": attr.string_list_dict(
            doc = "A mapping of group names to requirements within that group.",
        ),
        "repo_prefix": attr.string(
            doc = "Prefix used for the whl_library created components of each group",
        ),
    },
    implementation = _group_library_impl,
    doc = """
Create a package containing only wrapper py_library and whl_library rules for implementing dependency groups.
This is an implementation detail of dependency groups and should not be used alone.
    """,
)

# pip_repository implementation

def _format_list(items):
    return "[{}]".format(", ".join(items))

def _format_repr_list(strings):
    return _format_list(
        [repr(s) for s in strings],
    )

def _repr_dict(items):
    return {k: repr(v) for k, v in items.items()}

def _format_dict(items):
    return "{{{}}}".format(", ".join(sorted(['"{}": {}'.format(k, v) for k, v in items.items()])))
