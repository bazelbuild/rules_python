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

load("//python/private:auth.bzl", "AUTH_ATTRS", "get_auth")
load("//python/private:envsubst.bzl", "envsubst")
load("//python/private:python_repositories.bzl", "is_standalone_interpreter")
load("//python/private:repo_utils.bzl", "REPO_DEBUG_ENV_VAR", "repo_utils")
load(":attrs.bzl", "ATTRS", "use_isolated")
load(":deps.bzl", "all_repo_names")
load(":pypi_repo_utils.bzl", "pypi_repo_utils")
load(":whl_archive.bzl", "whl_archive_impl")

_CPPFLAGS = "CPPFLAGS"
_COMMAND_LINE_TOOLS_PATH_SLUG = "commandlinetools"

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
    if _COMMAND_LINE_TOOLS_PATH_SLUG not in xcode_root.lower():
        # This is a full xcode installation somewhere like /Applications/Xcode13.0.app/Contents/Developer
        # so we need to change the path to to the macos specific tools which are in a different relative
        # path than xcode installed command line tools.
        xcode_root = "{}/Platforms/MacOSX.platform/Developer".format(xcode_root)
    return [
        "-isysroot {}/SDKs/MacOSX.sdk".format(xcode_root),
    ]

def _get_toolchain_unix_cflags(rctx, python_interpreter, logger = None):
    """Gather cflags from a standalone toolchain for unix systems.

    Pip won't be able to compile c extensions from sdists with the pre built python distributions from indygreg
    otherwise. See https://github.com/indygreg/python-build-standalone/issues/103
    """

    # Only run on Unix systems
    if not rctx.os.name.lower().startswith(("mac os", "linux")):
        return []

    # Only update the location when using a standalone toolchain.
    if not is_standalone_interpreter(rctx, python_interpreter, logger = logger):
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

def _parse_optional_attrs(rctx, args, extra_pip_args = None):
    """Helper function to parse common attributes of pip_repository and whl_library repository rules.

    This function also serializes the structured arguments as JSON
    so they can be passed on the command line to subprocesses.

    Args:
        rctx: Handle to the rule repository context.
        args: A list of parsed args for the rule.
        extra_pip_args: The pip args to pass.
    Returns: Augmented args list.
    """

    if use_isolated(rctx, rctx.attr):
        args.append("--isolated")

    # Bazel version 7.1.0 and later (and rolling releases from version 8.0.0-pre.20240128.3)
    # support rctx.getenv(name, default): When building incrementally, any change to the value of
    # the variable named by name will cause this repository to be re-fetched.
    if "getenv" in dir(rctx):
        getenv = rctx.getenv
    else:
        getenv = rctx.os.environ.get

    # Check for None so we use empty default types from our attrs.
    # Some args want to be list, and some want to be dict.
    if extra_pip_args != None:
        args += [
            "--extra_pip_args",
            json.encode(struct(arg = [
                envsubst(pip_arg, rctx.attr.envsubst, getenv)
                for pip_arg in extra_pip_args
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

def _create_repository_execution_environment(rctx, python_interpreter, logger = None):
    """Create a environment dictionary for processes we spawn with rctx.execute.

    Args:
        rctx (repository_ctx): The repository context.
        python_interpreter (path): The resolved python interpreter.
        logger: Optional logger to use for operations.
    Returns:
        Dictionary of environment variable suitable to pass to rctx.execute.
    """

    # Gather any available CPPFLAGS values
    cppflags = []
    cppflags.extend(_get_xcode_location_cflags(rctx))
    cppflags.extend(_get_toolchain_unix_cflags(rctx, python_interpreter, logger = logger))

    env = {
        "PYTHONPATH": pypi_repo_utils.construct_pythonpath(
            rctx,
            entries = rctx.attr._python_path_entries,
        ),
        _CPPFLAGS: " ".join(cppflags),
    }

    return env

def _build_or_download_wheel(*, rctx, args, environment, logger):
    if rctx.attr.urls:
        op_tmpl = "whl_library.BuildWheelFromSource({name}, {requirement})"
    elif rctx.attr.download_only:
        op_tmpl = "whl_library.DownloadWheel({name}, {requirement})"
    else:
        op_tmpl = "whl_library.ResolveRequirement({name}, {requirement})"

    repo_utils.execute_checked(
        rctx,
        op = op_tmpl.format(name = rctx.attr.name, requirement = rctx.attr.requirement),
        arguments = args,
        environment = environment,
        quiet = rctx.attr.quiet,
        timeout = rctx.attr.timeout,
        logger = logger,
    )

    whl_path = rctx.path(json.decode(rctx.read("whl_file.json"))["whl_file"])
    if not rctx.delete("whl_file.json"):
        fail("failed to delete the whl_file.json file")

    return whl_path

def _whl_library_impl(rctx):
    logger = repo_utils.logger(rctx)
    python_interpreter = pypi_repo_utils.resolve_python_interpreter(
        rctx,
        python_interpreter = rctx.attr.python_interpreter,
        python_interpreter_target = rctx.attr.python_interpreter_target,
    )
    args = [
        python_interpreter,
        "-m",
        "python.private.pypi.whl_installer.wheel_installer",
        "--requirement",
        rctx.attr.requirement,
    ]
    extra_pip_args = []
    extra_pip_args.extend(rctx.attr.extra_pip_args)

    # Manually construct the PYTHONPATH since we cannot use the toolchain here
    environment = _create_repository_execution_environment(rctx, python_interpreter, logger = logger)

    whl_path = None
    need_to_build_to_use_pip = False
    if rctx.attr.whl_file:
        pass
    elif rctx.attr.urls:
        filename = rctx.attr.filename
        urls = rctx.attr.urls
        if not filename:
            _, _, filename = urls[0].rpartition("/")

        if not (filename.endswith(".whl") or filename.endswith("tar.gz") or filename.endswith(".zip")):
            if rctx.attr.filename:
                msg = "got '{}'".format(filename)
            else:
                msg = "detected '{}' from url:\n{}".format(filename, urls[0])
            fail("Only '.whl', '.tar.gz' or '.zip' files are supported, {}".format(msg))

        if not filename.endswith(".whl"):
            need_to_build_to_use_pip = True
            result = rctx.download(
                url = urls,
                output = filename,
                sha256 = rctx.attr.sha256,
                auth = get_auth(rctx, urls),
            )

            if not result.success:
                fail("could not download the '{}' from {}:\n{}".format(filename, urls, result))

            # It is an sdist and we need to tell PyPI to use a file in this directory
            # and, allow getting build dependencies from PYTHONPATH, which we
            # setup in this repository rule, but still download any necessary
            # build deps from PyPI (e.g. `flit_core`) if they are missing.
            extra_pip_args.extend(["--no-build-isolation", "--find-links", "."])
    else:
        need_to_build_to_use_pip = True

    args = _parse_optional_attrs(rctx, args, extra_pip_args)

    if not need_to_build_to_use_pip:
        whl_path = _build_or_download_wheel(rctx = rctx, args = args, environment = environment, logger = logger)

    whl_archive_impl(
        rctx = rctx,
        logger = logger,
        whl_path = whl_path,
    )

# NOTE @aignas 2024-03-21: The usage of dict({}, **common) ensures that all args to `dict` are unique
whl_library_attrs = dict({
    "annotation": attr.label(
        doc = (
            "Optional json encoded file containing annotation to apply to the extracted wheel. " +
            "See `package_annotation`"
        ),
        allow_files = True,
    ),
    "dep_template": attr.string(
        doc = """
The dep template to use for referencing the dependencies. It should have `{name}`
and `{target}` tokens that will be replaced with the normalized distribution name
and the target that we need respectively.
""",
    ),
    "filename": attr.string(
        doc = "Download the whl file to this filename. Only used when the `urls` is passed. If not specified, will be auto-detected from the `urls`.",
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
    "repo_prefix": attr.string(
        doc = """
Prefix for the generated packages will be of the form `@<prefix><sanitized-package-name>//...`

DEPRECATED. Only left for people who vendor requirements.bzl.
""",
    ),
    "requirement": attr.string(
        mandatory = True,
        doc = "Python requirement string describing the package to make available, if 'urls' or 'whl_file' is given, then this only needs to include foo[any_extras] as a bare minimum.",
    ),
    "sha256": attr.string(
        doc = "The sha256 of the downloaded whl. Only used when the `urls` is passed.",
    ),
    "urls": attr.string_list(
        doc = """\
The list of urls of the whl to be downloaded using bazel downloader. Using this
attr makes `extra_pip_args` and `download_only` ignored.""",
    ),
    "whl_file": attr.label(
        doc = "The whl file that should be used instead of downloading or building the whl.",
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
            for repo in all_repo_names
        ],
    ),
    "_rule_name": attr.string(default = "whl_library"),
}, **ATTRS)
whl_library_attrs.update(AUTH_ATTRS)

whl_library = repository_rule(
    attrs = whl_library_attrs,
    doc = """
Download and extracts a single wheel based into a bazel repo based on the requirement string passed in.
Instantiated from pip_repository and inherits config options from there.""",
    implementation = _whl_library_impl,
    environ = [
        "RULES_PYTHON_PIP_ISOLATED",
        REPO_DEBUG_ENV_VAR,
    ],
)
