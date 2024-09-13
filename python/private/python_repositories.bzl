# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""This file contains macros to be called during WORKSPACE evaluation.

For historic reasons, pip_repositories() is defined in //python:pip.bzl.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(
    "//python:versions.bzl",
    "DEFAULT_RELEASE_BASE_URL",
    "PLATFORMS",
    "TOOL_VERSIONS",
    "get_release_info",
)
load("//python/private/pypi:deps.bzl", "pypi_deps")
load(":auth.bzl", "get_auth")
load(":bzlmod_enabled.bzl", "BZLMOD_ENABLED")
load(":coverage_deps.bzl", "coverage_dep")
load(":full_version.bzl", "full_version")
load(":internal_config_repo.bzl", "internal_config_repo")
load(":repo_utils.bzl", "REPO_DEBUG_ENV_VAR", "repo_utils")
load(
    ":toolchains_repo.bzl",
    "host_toolchain",
    "multi_toolchain_aliases",
    "toolchain_aliases",
    "toolchains_repo",
)

def http_archive(**kwargs):
    maybe(_http_archive, **kwargs)

def py_repositories():
    """Runtime dependencies that users must install.

    This function should be loaded and called in the user's WORKSPACE.
    With bzlmod enabled, this function is not needed since MODULE.bazel handles transitive deps.
    """
    maybe(
        internal_config_repo,
        name = "rules_python_internal",
    )
    http_archive(
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        ],
    )
    http_archive(
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.0.9/rules_cc-0.0.9.tar.gz"],
        sha256 = "2037875b9a4456dce4a79d112a8ae885bbc4aad968e6587dca6e64f3a0900cdf",
        strip_prefix = "rules_cc-0.0.9",
    )
    pypi_deps()

########
# Remaining content of the file is only used to support toolchains.
########

STANDALONE_INTERPRETER_FILENAME = "STANDALONE_INTERPRETER"

def is_standalone_interpreter(rctx, python_interpreter_path, *, logger = None):
    """Query a python interpreter target for whether or not it's a rules_rust provided toolchain

    Args:
        rctx: {type}`repository_ctx` The repository rule's context object.
        python_interpreter_path: {type}`path` A path representing the interpreter.
        logger: Optional logger to use for operations.

    Returns:
        {type}`bool` Whether or not the target is from a rules_python generated toolchain.
    """

    # Only update the location when using a hermetic toolchain.
    if not python_interpreter_path:
        return False

    # This is a rules_python provided toolchain.
    return repo_utils.execute_unchecked(
        rctx,
        op = "IsStandaloneInterpreter",
        arguments = [
            "ls",
            "{}/{}".format(
                python_interpreter_path.dirname,
                STANDALONE_INTERPRETER_FILENAME,
            ),
        ],
        logger = logger,
    ).return_code == 0

def _python_repository_impl(rctx):
    if rctx.attr.distutils and rctx.attr.distutils_content:
        fail("Only one of (distutils, distutils_content) should be set.")
    if bool(rctx.attr.url) == bool(rctx.attr.urls):
        fail("Exactly one of (url, urls) must be set.")

    logger = repo_utils.logger(rctx)

    platform = rctx.attr.platform
    python_version = rctx.attr.python_version
    python_version_info = python_version.split(".")
    python_short_version = "{0}.{1}".format(*python_version_info)
    release_filename = rctx.attr.release_filename
    urls = rctx.attr.urls or [rctx.attr.url]
    auth = get_auth(rctx, urls)

    if release_filename.endswith(".zst"):
        rctx.download(
            url = urls,
            sha256 = rctx.attr.sha256,
            output = release_filename,
            auth = auth,
        )
        unzstd = rctx.which("unzstd")
        if not unzstd:
            url = rctx.attr.zstd_url.format(version = rctx.attr.zstd_version)
            rctx.download_and_extract(
                url = url,
                sha256 = rctx.attr.zstd_sha256,
                auth = auth,
            )
            working_directory = "zstd-{version}".format(version = rctx.attr.zstd_version)

            repo_utils.execute_checked(
                rctx,
                op = "python_repository.MakeZstd",
                arguments = [
                    repo_utils.which_checked(rctx, "make"),
                    "--jobs=4",
                ],
                timeout = 600,
                quiet = True,
                working_directory = working_directory,
                logger = logger,
            )
            zstd = "{working_directory}/zstd".format(working_directory = working_directory)
            unzstd = "./unzstd"
            rctx.symlink(zstd, unzstd)

        repo_utils.execute_checked(
            rctx,
            op = "python_repository.ExtractRuntime",
            arguments = [
                repo_utils.which_checked(rctx, "tar"),
                "--extract",
                "--strip-components=2",
                "--use-compress-program={unzstd}".format(unzstd = unzstd),
                "--file={}".format(release_filename),
            ],
            logger = logger,
        )
    else:
        rctx.download_and_extract(
            url = urls,
            sha256 = rctx.attr.sha256,
            stripPrefix = rctx.attr.strip_prefix,
            auth = auth,
        )

    patches = rctx.attr.patches
    if patches:
        for patch in patches:
            # Should take the strip as an attr, but this is fine for the moment
            rctx.patch(patch, strip = rctx.attr.patch_strip)

    # Write distutils.cfg to the Python installation.
    if "windows" in platform:
        distutils_path = "Lib/distutils/distutils.cfg"
    else:
        distutils_path = "lib/python{}/distutils/distutils.cfg".format(python_short_version)
    if rctx.attr.distutils:
        rctx.file(distutils_path, rctx.read(rctx.attr.distutils))
    elif rctx.attr.distutils_content:
        rctx.file(distutils_path, rctx.attr.distutils_content)

    if "darwin" in platform and "osx" == repo_utils.get_platforms_os_name(rctx):
        # Fix up the Python distribution's LC_ID_DYLIB field.
        # It points to a build directory local to the GitHub Actions
        # host machine used in the Python standalone build, which causes
        # dyld lookup errors. To fix, set the full path to the dylib as
        # it appears in the Bazel workspace as its LC_ID_DYLIB using
        # the `install_name_tool` bundled with macOS.
        dylib = "lib/libpython{}.dylib".format(python_short_version)
        full_dylib_path = rctx.path(dylib)
        repo_utils.execute_checked(
            rctx,
            op = "python_repository.FixUpDyldIdPath",
            arguments = [repo_utils.which_checked(rctx, "install_name_tool"), "-id", full_dylib_path, dylib],
            logger = logger,
        )

    # Make the Python installation read-only. This is to prevent issues due to
    # pycs being generated at runtime:
    # * The pycs are not deterministic (they contain timestamps)
    # * Multiple processes trying to write the same pycs can result in errors.
    if not rctx.attr.ignore_root_user_error:
        if "windows" not in platform:
            lib_dir = "lib" if "windows" not in platform else "Lib"

            repo_utils.execute_checked(
                rctx,
                op = "python_repository.MakeReadOnly",
                arguments = [repo_utils.which_checked(rctx, "chmod"), "-R", "ugo-w", lib_dir],
                logger = logger,
            )
            exec_result = repo_utils.execute_unchecked(
                rctx,
                op = "python_repository.TestReadOnly",
                arguments = [repo_utils.which_checked(rctx, "touch"), "{}/.test".format(lib_dir)],
                logger = logger,
            )

            # The issue with running as root is the installation is no longer
            # read-only, so the problems due to pyc can resurface.
            if exec_result.return_code == 0:
                stdout = repo_utils.execute_checked_stdout(
                    rctx,
                    op = "python_repository.GetUserId",
                    arguments = [repo_utils.which_checked(rctx, "id"), "-u"],
                    logger = logger,
                )
                uid = int(stdout.strip())
                if uid == 0:
                    fail("The current user is root, please run as non-root when using the hermetic Python interpreter. See https://github.com/bazelbuild/rules_python/pull/713.")
                else:
                    fail("The current user has CAP_DAC_OVERRIDE set, please drop this capability when using the hermetic Python interpreter. See https://github.com/bazelbuild/rules_python/pull/713.")

    python_bin = "python.exe" if ("windows" in platform) else "bin/python3"

    glob_include = []
    glob_exclude = [
        "**/* *",  # Bazel does not support spaces in file names.
        # Unused shared libraries. `python` executable and the `:libpython` target
        # depend on `libpython{python_version}.so.1.0`.
        "lib/libpython{python_version}.so".format(python_version = python_short_version),
        # static libraries
        "lib/**/*.a",
        # tests for the standard libraries.
        "lib/python{python_version}/**/test/**".format(python_version = python_short_version),
        "lib/python{python_version}/**/tests/**".format(python_version = python_short_version),
        "**/__pycache__/*.pyc.*",  # During pyc creation, temp files named *.pyc.NNN are created
    ]

    if "linux" in platform:
        # Workaround around https://github.com/indygreg/python-build-standalone/issues/231
        for url in urls:
            head_and_release, _, _ = url.rpartition("/")
            _, _, release = head_and_release.rpartition("/")
            if not release.isdigit():
                # Maybe this is some custom toolchain, so skip this
                break

            if int(release) >= 20240224:
                # Starting with this release the Linux toolchains have infinite symlink loop
                # on host platforms that are not Linux. Delete the files no
                # matter the host platform so that the cross-built artifacts
                # are the same irrespective of the host platform we are
                # building on.
                #
                # Link to the first affected release:
                # https://github.com/indygreg/python-build-standalone/releases/tag/20240224
                rctx.delete("share/terminfo")
                break

    if rctx.attr.ignore_root_user_error or "windows" in platform:
        glob_exclude += [
            # These pycache files are created on first use of the associated python files.
            # Exclude them from the glob because otherwise between the first time and second time a python toolchain is used,"
            # the definition of this filegroup will change, and depending rules will get invalidated."
            # See https://github.com/bazelbuild/rules_python/issues/1008 for unconditionally adding these to toolchains so we can stop ignoring them."
            "**/__pycache__/*.pyc",
            "**/__pycache__/*.pyo",
        ]

    if "windows" in platform:
        glob_include += [
            "*.exe",
            "*.dll",
            "bin/**",
            "DLLs/**",
            "extensions/**",
            "include/**",
            "Lib/**",
            "libs/**",
            "Scripts/**",
            "share/**",
            "tcl/**",
        ]
    else:
        glob_include += [
            "bin/**",
            "extensions/**",
            "include/**",
            "lib/**",
            "libs/**",
            "share/**",
        ]

    if rctx.attr.coverage_tool:
        if "windows" in platform:
            coverage_tool = None
        else:
            coverage_tool = '"{}"'.format(rctx.attr.coverage_tool)

        coverage_attr_text = """\
    coverage_tool = select({{
        ":coverage_enabled": {coverage_tool},
        "//conditions:default": None
    }}),
""".format(coverage_tool = coverage_tool)
    else:
        coverage_attr_text = "    # coverage_tool attribute not supported by this Bazel version"

    build_content = """\
# Generated by python/repositories.bzl

load("@rules_python//python:py_runtime.bzl", "py_runtime")
load("@rules_python//python:py_runtime_pair.bzl", "py_runtime_pair")
load("@rules_python//python/cc:py_cc_toolchain.bzl", "py_cc_toolchain")
load("@rules_python//python/private:py_exec_tools_toolchain.bzl", "py_exec_tools_toolchain")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "files",
    srcs = glob(
        include = {glob_include},
        # Platform-agnostic filegroup can't match on all patterns.
        allow_empty = True,
        exclude = {glob_exclude},
    ),
)

cc_import(
    name = "interface",
    interface_library = "libs/python{python_version_nodot}.lib",
    system_provided = True,
)

filegroup(
    name = "includes",
    srcs = glob(["include/**/*.h"]),
)

cc_library(
    name = "python_headers",
    deps = select({{
        "@bazel_tools//src/conditions:windows": [":interface"],
        "//conditions:default": None,
    }}),
    hdrs = [":includes"],
    includes = [
        "include",
        "include/python{python_version}",
        "include/python{python_version}m",
    ],
)

cc_library(
    name = "libpython",
    hdrs = [":includes"],
    srcs = select({{
        "@platforms//os:windows": ["python3.dll", "libs/python{python_version_nodot}.lib"],
        "@platforms//os:macos": ["lib/libpython{python_version}.dylib"],
        "@platforms//os:linux": ["lib/libpython{python_version}.so", "lib/libpython{python_version}.so.1.0"],
    }}),
)

exports_files(["python", "{python_path}"])

# Used to only download coverage toolchain when the coverage is collected by
# bazel.
config_setting(
    name = "coverage_enabled",
    values = {{"collect_code_coverage": "true"}},
    visibility = ["//visibility:private"],
)

py_runtime(
    name = "py3_runtime",
    files = [":files"],
{coverage_attr}
    interpreter = "{python_path}",
    interpreter_version_info = {{
        "major": "{interpreter_version_info_major}",
        "minor": "{interpreter_version_info_minor}",
        "micro": "{interpreter_version_info_micro}",
    }},
    python_version = "PY3",
    implementation_name = 'cpython',
    pyc_tag = "cpython-{interpreter_version_info_major}{interpreter_version_info_minor}",
)

py_runtime_pair(
    name = "python_runtimes",
    py2_runtime = None,
    py3_runtime = ":py3_runtime",
)

py_cc_toolchain(
    name = "py_cc_toolchain",
    headers = ":python_headers",
    libs = ":libpython",
    python_version = "{python_version}",
)

py_exec_tools_toolchain(
    name = "py_exec_tools_toolchain",
    precompiler = "@rules_python//tools/precompiler:precompiler",
)
""".format(
        glob_exclude = repr(glob_exclude),
        glob_include = repr(glob_include),
        python_path = python_bin,
        python_version = python_short_version,
        python_version_nodot = python_short_version.replace(".", ""),
        coverage_attr = coverage_attr_text,
        interpreter_version_info_major = python_version_info[0],
        interpreter_version_info_minor = python_version_info[1],
        interpreter_version_info_micro = python_version_info[2],
    )
    rctx.delete("python")
    rctx.symlink(python_bin, "python")
    rctx.file(STANDALONE_INTERPRETER_FILENAME, "# File intentionally left blank. Indicates that this is an interpreter repo created by rules_python.")
    rctx.file("BUILD.bazel", build_content)

    attrs = {
        "auth_patterns": rctx.attr.auth_patterns,
        "coverage_tool": rctx.attr.coverage_tool,
        "distutils": rctx.attr.distutils,
        "distutils_content": rctx.attr.distutils_content,
        "ignore_root_user_error": rctx.attr.ignore_root_user_error,
        "name": rctx.attr.name,
        "netrc": rctx.attr.netrc,
        "patch_strip": rctx.attr.patch_strip,
        "patches": rctx.attr.patches,
        "platform": platform,
        "python_version": python_version,
        "release_filename": release_filename,
        "sha256": rctx.attr.sha256,
        "strip_prefix": rctx.attr.strip_prefix,
    }

    if rctx.attr.url:
        attrs["url"] = rctx.attr.url
    else:
        attrs["urls"] = urls

    return attrs

python_repository = repository_rule(
    _python_repository_impl,
    doc = "Fetches the external tools needed for the Python toolchain.",
    attrs = {
        "auth_patterns": attr.string_dict(
            doc = "Override mapping of hostnames to authorization patterns; mirrors the eponymous attribute from http_archive",
        ),
        "coverage_tool": attr.string(
            # Mirrors the definition at
            # https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/python/py_runtime_rule.bzl
            doc = """
This is a target to use for collecting code coverage information from `py_binary`
and `py_test` targets.

If set, the target must either produce a single file or be an executable target.
The path to the single file, or the executable if the target is executable,
determines the entry point for the python coverage tool.  The target and its
runfiles will be added to the runfiles when coverage is enabled.

The entry point for the tool must be loadable by a Python interpreter (e.g. a
`.py` or `.pyc` file).  It must accept the command line arguments
of coverage.py (https://coverage.readthedocs.io), at least including
the `run` and `lcov` subcommands.

The target is accepted as a string by the python_repository and evaluated within
the context of the toolchain repository.

For more information see the official bazel docs
(https://bazel.build/reference/be/python#py_runtime.coverage_tool).
""",
        ),
        "distutils": attr.label(
            allow_single_file = True,
            doc = "A distutils.cfg file to be included in the Python installation. " +
                  "Either distutils or distutils_content can be specified, but not both.",
            mandatory = False,
        ),
        "distutils_content": attr.string(
            doc = "A distutils.cfg file content to be included in the Python installation. " +
                  "Either distutils or distutils_content can be specified, but not both.",
            mandatory = False,
        ),
        "ignore_root_user_error": attr.bool(
            default = False,
            doc = "Whether the check for root should be ignored or not. This causes cache misses with .pyc files.",
            mandatory = False,
        ),
        "netrc": attr.string(
            doc = ".netrc file to use for authentication; mirrors the eponymous attribute from http_archive",
        ),
        "patch_strip": attr.int(
            doc = """
Same as the --strip argument of Unix patch.

:::{note}
In the future the default value will be set to `0`, to mimic the well known
function defaults (e.g. `single_version_override` for `MODULE.bazel` files.
:::

:::{versionadded} 0.36.0
:::
""",
            default = 1,
            mandatory = False,
        ),
        "patches": attr.label_list(
            doc = "A list of patch files to apply to the unpacked interpreter",
            mandatory = False,
        ),
        "platform": attr.string(
            doc = "The platform name for the Python interpreter tarball.",
            mandatory = True,
            values = PLATFORMS.keys(),
        ),
        "python_version": attr.string(
            doc = "The Python version.",
            mandatory = True,
        ),
        "release_filename": attr.string(
            doc = "The filename of the interpreter to be downloaded",
            mandatory = True,
        ),
        "sha256": attr.string(
            doc = "The SHA256 integrity hash for the Python interpreter tarball.",
            mandatory = True,
        ),
        "strip_prefix": attr.string(
            doc = "A directory prefix to strip from the extracted files.",
        ),
        "url": attr.string(
            doc = "The URL of the interpreter to download. Exactly one of url and urls must be set.",
        ),
        "urls": attr.string_list(
            doc = "The URL of the interpreter to download. Exactly one of url and urls must be set.",
        ),
        "zstd_sha256": attr.string(
            default = "7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0",
        ),
        "zstd_url": attr.string(
            default = "https://github.com/facebook/zstd/releases/download/v{version}/zstd-{version}.tar.gz",
        ),
        "zstd_version": attr.string(
            default = "1.5.2",
        ),
        "_rule_name": attr.string(default = "python_repository"),
    },
    environ = [REPO_DEBUG_ENV_VAR],
)

# Wrapper macro around everything above, this is the primary API.
def python_register_toolchains(
        name,
        python_version,
        register_toolchains = True,
        register_coverage_tool = False,
        set_python_version_constraint = False,
        tool_versions = None,
        **kwargs):
    """Convenience macro for users which does typical setup.

    - Create a repository for each built-in platform like "python_3_8_linux_amd64" -
      this repository is lazily fetched when Python is needed for that platform.
    - Create a repository exposing toolchains for each platform like
      "python_platforms".
    - Register a toolchain pointing at each platform.

    Users can avoid this macro and do these steps themselves, if they want more
    control.

    Args:
        name: {type}`str` base name for all created repos, e.g. "python_3_8".
        python_version: {type}`str` the Python version.
        register_toolchains: {type}`bool` Whether or not to register the downloaded toolchains.
        register_coverage_tool: {type}`bool` Whether or not to register the
            downloaded coverage tool to the toolchains.
        set_python_version_constraint: {type}`bool` When set to `True`,
            `target_compatible_with` for the toolchains will include a version
            constraint.
        tool_versions: {type}`dict` contains a mapping of version with SHASUM
            and platform info. If not supplied, the defaults in
            python/versions.bzl will be used.
        **kwargs: passed to each {obj}`python_repository` call.
    """

    if BZLMOD_ENABLED:
        # you cannot used native.register_toolchains when using bzlmod.
        register_toolchains = False

    base_url = kwargs.pop("base_url", DEFAULT_RELEASE_BASE_URL)
    tool_versions = tool_versions or TOOL_VERSIONS

    python_version = full_version(python_version)

    toolchain_repo_name = "{name}_toolchains".format(name = name)

    # When using unreleased Bazel versions, the version is an empty string
    if native.bazel_version:
        bazel_major = int(native.bazel_version.split(".")[0])
        if bazel_major < 6:
            if register_coverage_tool:
                # buildifier: disable=print
                print((
                    "WARNING: ignoring register_coverage_tool=True when " +
                    "registering @{name}: Bazel 6+ required, got {version}"
                ).format(
                    name = name,
                    version = native.bazel_version,
                ))
            register_coverage_tool = False

    loaded_platforms = []
    for platform in PLATFORMS.keys():
        sha256 = tool_versions[python_version]["sha256"].get(platform, None)
        if not sha256:
            continue

        loaded_platforms.append(platform)
        (release_filename, urls, strip_prefix, patches, patch_strip) = get_release_info(platform, python_version, base_url, tool_versions)

        # allow passing in a tool version
        coverage_tool = None
        coverage_tool = tool_versions[python_version].get("coverage_tool", {}).get(platform, None)
        if register_coverage_tool and coverage_tool == None:
            coverage_tool = coverage_dep(
                name = "{name}_{platform}_coverage".format(
                    name = name,
                    platform = platform,
                ),
                python_version = python_version,
                platform = platform,
                visibility = ["@{name}_{platform}//:__subpackages__".format(
                    name = name,
                    platform = platform,
                )],
            )

        python_repository(
            name = "{name}_{platform}".format(
                name = name,
                platform = platform,
            ),
            sha256 = sha256,
            patches = patches,
            patch_strip = patch_strip,
            platform = platform,
            python_version = python_version,
            release_filename = release_filename,
            urls = urls,
            strip_prefix = strip_prefix,
            coverage_tool = coverage_tool,
            **kwargs
        )
        if register_toolchains:
            native.register_toolchains("@{toolchain_repo_name}//:{platform}_toolchain".format(
                toolchain_repo_name = toolchain_repo_name,
                platform = platform,
            ))
            native.register_toolchains("@{toolchain_repo_name}//:{platform}_py_cc_toolchain".format(
                toolchain_repo_name = toolchain_repo_name,
                platform = platform,
            ))
            native.register_toolchains("@{toolchain_repo_name}//:{platform}_py_exec_tools_toolchain".format(
                toolchain_repo_name = toolchain_repo_name,
                platform = platform,
            ))

    host_toolchain(name = name + "_host")

    toolchain_aliases(
        name = name,
        python_version = python_version,
        user_repository_name = name,
        platforms = loaded_platforms,
    )

    # in bzlmod we write out our own toolchain repos
    if BZLMOD_ENABLED:
        return

    toolchains_repo(
        name = toolchain_repo_name,
        python_version = python_version,
        set_python_version_constraint = set_python_version_constraint,
        user_repository_name = name,
    )

def python_register_multi_toolchains(
        name,
        python_versions,
        default_version = None,
        **kwargs):
    """Convenience macro for registering multiple Python toolchains.

    Args:
        name: {type}`str` base name for each name in {obj}`python_register_toolchains` call.
        python_versions: {type}`list[str]` the Python versions.
        default_version: {type}`str` the default Python version. If not set,
            the first version in python_versions is used.
        **kwargs: passed to each {obj}`python_register_toolchains` call.
    """
    if len(python_versions) == 0:
        fail("python_versions must not be empty")

    if not default_version:
        default_version = python_versions.pop(0)
    for python_version in python_versions:
        if python_version == default_version:
            # We register the default version lastly so that it's not picked first when --platforms
            # is set with a constraint during toolchain resolution. This is due to the fact that
            # Bazel will match the unconstrained toolchain if we register it before the constrained
            # ones.
            continue
        python_register_toolchains(
            name = name + "_" + python_version.replace(".", "_"),
            python_version = python_version,
            set_python_version_constraint = True,
            **kwargs
        )
    python_register_toolchains(
        name = name + "_" + default_version.replace(".", "_"),
        python_version = default_version,
        set_python_version_constraint = False,
        **kwargs
    )

    multi_toolchain_aliases(
        name = name,
        python_versions = {
            python_version: name + "_" + python_version.replace(".", "_")
            for python_version in (python_versions + [default_version])
        },
    )
