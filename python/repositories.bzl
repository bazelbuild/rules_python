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

load("//python/private:toolchains_repo.bzl", "resolved_interpreter_os_alias", "toolchains_repo")
load(
    ":versions.bzl",
    "DEFAULT_RELEASE_BASE_URL",
    "MINOR_MAPPING",
    "PLATFORMS",
    "TOOL_VERSIONS",
    "get_release_url",
)

def py_repositories():
    # buildifier: disable=print
    print("py_repositories is a no-op and is deprecated. You can remove this from your WORKSPACE file")

########
# Remaining content of the file is only used to support toolchains.
########

STANDALONE_INTERPRETER_FILENAME = "STANDALONE_INTERPRETER"

def is_standalone_interpreter(rctx, python_interpreter_target):
    """Query a python interpreter target for whether or not it's a rules_rust provided toolchain

    Args:
        rctx (repository_ctx): The repository rule's context object.
        python_interpreter_target (Target): A target representing a python interpreter.

    Returns:
        bool: Whether or not the target is from a rules_python generated toolchain.
    """

    # Only update the location when using a hermetic toolchain.
    if not python_interpreter_target:
        return False

    # This is a rules_python provided toolchain.
    return rctx.execute([
        "ls",
        "{}/{}".format(
            rctx.path(Label("@{}//:WORKSPACE".format(rctx.attr.python_interpreter_target.workspace_name))).dirname,
            STANDALONE_INTERPRETER_FILENAME,
        ),
    ]).return_code == 0

def _python_repository_impl(rctx):
    if rctx.attr.distutils and rctx.attr.distutils_content:
        fail("Only one of (distutils, distutils_content) should be set.")

    platform = rctx.attr.platform
    python_version = rctx.attr.python_version
    python_short_version = python_version.rpartition(".")[0]
    release_filename = rctx.attr.release_filename
    url = rctx.attr.url

    if release_filename.endswith(".zst"):
        rctx.download(
            url = url,
            sha256 = rctx.attr.sha256,
            output = release_filename,
        )
        unzstd = rctx.which("unzstd")
        if not unzstd:
            url = rctx.attr.zstd_url.format(version = rctx.attr.zstd_version)
            rctx.download_and_extract(
                url = url,
                sha256 = rctx.attr.zstd_sha256,
            )
            working_directory = "zstd-{version}".format(version = rctx.attr.zstd_version)
            make_result = rctx.execute(
                ["make", "--jobs=4"],
                timeout = 600,
                quiet = True,
                working_directory = working_directory,
            )
            if make_result.return_code:
                fail_msg = (
                    "Failed to compile 'zstd' from source for use in Python interpreter extraction. " +
                    "'make' error message: {}".format(make_result.stderr)
                )
                fail(fail_msg)
            zstd = "{working_directory}/zstd".format(working_directory = working_directory)
            unzstd = "./unzstd"
            rctx.symlink(zstd, unzstd)

        exec_result = rctx.execute([
            "tar",
            "--extract",
            "--strip-components=2",
            "--use-compress-program={unzstd}".format(unzstd = unzstd),
            "--file={}".format(release_filename),
        ])
        if exec_result.return_code:
            fail_msg = (
                "Failed to extract Python interpreter from '{}'. ".format(release_filename) +
                "'tar' error message: {}".format(exec_result.stderr)
            )
            fail(fail_msg)
    else:
        rctx.download_and_extract(
            url = url,
            sha256 = rctx.attr.sha256,
            stripPrefix = rctx.attr.strip_prefix,
        )

    # Write distutils.cfg to the Python installation.
    if "windows" in rctx.os.name:
        distutils_path = "Lib/distutils/distutils.cfg"
    else:
        distutils_path = "lib/python{}/distutils/distutils.cfg".format(python_short_version)
    if rctx.attr.distutils:
        rctx.file(distutils_path, rctx.read(rctx.attr.distutils))
    elif rctx.attr.distutils_content:
        rctx.file(distutils_path, rctx.attr.distutils_content)

    # Make the Python installation read-only.
    if not rctx.attr.ignore_root_user_error:
        if "windows" not in rctx.os.name:
            lib_dir = "lib" if "windows" not in platform else "Lib"
            exec_result = rctx.execute(["chmod", "-R", "ugo-w", lib_dir])
            if exec_result.return_code != 0:
                fail_msg = "Failed to make interpreter installation read-only. 'chmod' error msg: {}".format(
                    exec_result.stderr,
                )
                fail(fail_msg)
            exec_result = rctx.execute(["touch", "{}/.test".format(lib_dir)])
            if exec_result.return_code == 0:
                exec_result = rctx.execute(["id", "-u"])
                if exec_result.return_code != 0:
                    fail("Could not determine current user ID. 'id -u' error msg: {}".format(
                        exec_result.stderr,
                    ))
                uid = int(exec_result.stdout.strip())
                if uid == 0:
                    fail("The current user is root, please run as non-root when using the hermetic Python interpreter. See https://github.com/bazelbuild/rules_python/pull/713.")
                else:
                    fail("The current user has CAP_DAC_OVERRIDE set, please drop this capability when using the hermetic Python interpreter. See https://github.com/bazelbuild/rules_python/pull/713.")

    python_bin = "python.exe" if ("windows" in platform) else "bin/python3"

    if "windows" in platform:
        glob_include = [
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
        ]
    else:
        glob_include = [
            "bin/**",
            "extensions/**",
            "include/**",
            "lib/**",
            "libs/**",
            "share/**",
        ]

    build_content = """\
# Generated by python/repositories.bzl

load("@bazel_tools//tools/python:toolchain.bzl", "py_runtime_pair")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "files",
    srcs = glob(
        include = {glob_include},
        # Platform-agnostic filegroup can't match on all patterns.
        allow_empty = True,
        exclude = [
            "**/* *", # Bazel does not support spaces in file names.
            # Unused shared libraries. `python` executable and the `:libpython` target
            # depend on `libpython{python_version}.so.1.0`.
            "lib/libpython{python_version}.so",
            # static libraries
            "lib/**/*.a",
            # tests for the standard libraries.
            "lib/python{python_version}/**/test/**",
            "lib/python{python_version}/**/tests/**",
        ],
    ),
)

filegroup(
    name = "includes",
    srcs = glob(["include/**/*.h"]),
)

cc_library(
    name = "python_headers",
    hdrs = [":includes"],
    includes = [
        "include",
        "include/python{python_version}",
        "include/python{python_version}m",
    ],
)

cc_import(
    name = "libpython",
    hdrs = [":includes"],
    shared_library = select({{
        "@platforms//os:windows": "python3.dll",
        "@platforms//os:macos": "lib/libpython{python_version}.dylib",
        "@platforms//os:linux": "lib/libpython{python_version}.so.1.0",
    }}),
)

exports_files(["python", "{python_path}"])

py_runtime(
    name = "py3_runtime",
    files = [":files"],
    interpreter = "{python_path}",
    python_version = "PY3",
)

py_runtime_pair(
    name = "python_runtimes",
    py2_runtime = None,
    py3_runtime = ":py3_runtime",
)
""".format(
        glob_include = repr(glob_include),
        python_path = python_bin,
        python_version = python_short_version,
    )
    rctx.symlink(python_bin, "python")
    rctx.file(STANDALONE_INTERPRETER_FILENAME, "# File intentionally left blank. Indicates that this is an interpreter repo created by rules_python.")
    rctx.file("BUILD.bazel", build_content)

    return {
        "distutils": rctx.attr.distutils,
        "distutils_content": rctx.attr.distutils_content,
        "name": rctx.attr.name,
        "platform": platform,
        "python_version": python_version,
        "release_filename": release_filename,
        "sha256": rctx.attr.sha256,
        "strip_prefix": rctx.attr.strip_prefix,
        "url": url,
    }

python_repository = repository_rule(
    _python_repository_impl,
    doc = "Fetches the external tools needed for the Python toolchain.",
    attrs = {
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
            mandatory = True,
        ),
        "url": attr.string(
            doc = "The URL of the interpreter to download",
            mandatory = True,
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
    },
)

# Wrapper macro around everything above, this is the primary API.
def python_register_toolchains(
        name,
        python_version,
        distutils = None,
        distutils_content = None,
        register_toolchains = True,
        tool_versions = TOOL_VERSIONS,
        **kwargs):
    """Convenience macro for users which does typical setup.

    - Create a repository for each built-in platform like "python_linux_amd64" -
      this repository is lazily fetched when Python is needed for that platform.
    - Create a repository exposing toolchains for each platform like
      "python_platforms".
    - Register a toolchain pointing at each platform.
    Users can avoid this macro and do these steps themselves, if they want more
    control.
    Args:
        name: base name for all created repos, like "python38".
        python_version: the Python version.
        distutils: see the distutils attribute in the python_repository repository rule.
        distutils_content: see the distutils_content attribute in the python_repository repository rule.
        register_toolchains: Whether or not to register the downloaded toolchains.
        tool_versions: a dict containing a mapping of version with SHASUM and platform info. If not supplied, the defaults
        in python/versions.bzl will be used
        **kwargs: passed to each python_repositories call.
    """
    base_url = kwargs.pop("base_url", DEFAULT_RELEASE_BASE_URL)

    if python_version in MINOR_MAPPING:
        python_version = MINOR_MAPPING[python_version]

    for platform in PLATFORMS.keys():
        sha256 = tool_versions[python_version]["sha256"].get(platform, None)
        if not sha256:
            continue

        (release_filename, url, strip_prefix) = get_release_url(platform, python_version, base_url, tool_versions)

        python_repository(
            name = "{name}_{platform}".format(
                name = name,
                platform = platform,
            ),
            sha256 = sha256,
            platform = platform,
            python_version = python_version,
            release_filename = release_filename,
            url = url,
            distutils = distutils,
            distutils_content = distutils_content,
            strip_prefix = strip_prefix,
            **kwargs
        )
        if register_toolchains:
            native.register_toolchains("@{name}_toolchains//:{platform}_toolchain".format(
                name = name,
                platform = platform,
            ))

    resolved_interpreter_os_alias(
        name = name,
        user_repository_name = name,
    )

    toolchains_repo(
        name = "{name}_toolchains".format(name = name),
        user_repository_name = name,
    )
