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

"""Create a repository to hold the toolchains.

This follows guidance here:
https://docs.bazel.build/versions/main/skylark/deploying.html#registering-toolchains

The "complex computation" in our case is simply downloading large artifacts.
This guidance tells us how to avoid that: we put the toolchain targets in the
alias repository with only the toolchain attribute pointing into the
platform-specific repositories.
"""

PLATFORMS = {
    "aarch64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
        # Matches the value returned from:
        # repository_ctx.os.name.lower()
        os_name = "mac os",
        # Matches the value returned from:
        # repository_ctx.execute(["uname", "-m"]).stdout.strip()
        arch = "arm64",
    ),
    "x86_64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
        # See comments above.
        os_name = "mac os",
        arch = "x86_64",
    ),
    "x86_64-pc-windows-msvc": struct(
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
        # See comments above.
        os_name = "windows",
        arch = "x86_64",
    ),
    "x86_64-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
        # See comments above.
        os_name = "linux",
        arch = "x86_64",
    ),
}

def host_platform(rctx):
    """Infer the host platform from a repository context.

    Args:
        rctx: Bazel's repository_ctx
    Returns:
        a key from the PLATFORMS dictionary
    """
    os_name = rctx.os.name

    # We assume the arch for Windows is always x86_64.
    if "windows" in os_name.lower():
        arch = "x86_64"

        # Normalize the os_name. E.g. os_name could be "OS windows server 2019".
        os_name = "windows"
    else:
        # This is not ideal, but bazel doesn't directly expose arch.
        arch = rctx.execute(["uname", "-m"]).stdout.strip()

        # Normalize the os_name.
        if "mac" in os_name.lower():
            os_name = "mac os"
        elif "linux" in os_name.lower():
            os_name = "linux"

    for platform, meta in PLATFORMS.items():
        if meta.os_name == os_name and meta.arch == arch:
            return platform
    fail("No platform declared for host OS {} on arch {}".format(os_name, arch))

def _toolchains_repo_impl(repository_ctx):
    build_content = """\
# Generated by toolchains_repo.bzl
#
# These can be registered in the workspace file or passed to --extra_toolchains
# flag. By default all these toolchains are registered by the
# python_register_toolchains macro so you don't normally need to interact with
# these targets.

"""

    for [platform, meta] in PLATFORMS.items():
        build_content += """\
toolchain(
    name = "{platform}_toolchain",
    exec_compatible_with = {compatible_with},
    target_compatible_with = {compatible_with},
    toolchain = "@{user_repository_name}_{platform}//:python_runtimes",
    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
)
""".format(
            platform = platform,
            name = repository_ctx.attr.name,
            user_repository_name = repository_ctx.attr.user_repository_name,
            compatible_with = meta.compatible_with,
        )

    repository_ctx.file("BUILD.bazel", build_content)

toolchains_repo = repository_rule(
    _toolchains_repo_impl,
    doc = "Creates a repository with toolchain definitions for all known platforms " +
          "which can be registered or selected.",
    attrs = {
        "user_repository_name": attr.string(doc = "what the user chose for the base name"),
    },
)
