# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""A simple extension to install `uv` to be used within the `pip` bzlmod extension."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":text_util.bzl", "render")

def _get_cpu(f):
    f = f.lower()
    if "x86_64" in f or "amd64" in f:
        return "x86_64"

    if "aarch64" in f:
        return "aarch64"

    if "powerpc" in f:
        return "ppc"

    if "s390x" in f:
        return "s390x"

    fail("Could not determine cpu for '{}'".format(f))

def _get_os(f):
    f = f.lower()
    if "windows" in f:
        return "windows"

    if "linux" in f:
        return "linux"

    if "darwin" in f:
        return "osx"

    fail("Could not determine os for '{}'".format(f))

def _impl(rctx):
    constraints = {
        "{}_{}".format(_get_os(f), _get_cpu(f)): [
            "@platforms//cpu:" + _get_cpu(f),
            "@platforms//os:" + _get_os(f),
        ]
        for f in rctx.attr.filenames
    }

    rctx.file(
        "BUILD.bazel",
        "\n\n".join(
            [
                """load("@bazel_skylib//rules:native_binary.bzl", "native_binary")""",
                render.call(
                    rule = "native_binary",
                    name = repr("uv"),
                    src = render.select(
                        {
                            ":is_" + os_arch: "@{}_{}//:{}".format(
                                rctx.attr.hub_name,
                                os_arch,
                                "uv" if "windows" not in os_arch else "uv.exe",
                            )
                            for os_arch in constraints.keys()
                        },
                        no_match_error = repr("'uv' is not available for your host platform"),
                    ),
                    out = render.select({
                        "@platforms//os:windows": "uv.exe",
                        "//conditions:default": "uv",
                    }),
                    visibility = render.list(["@rules_python//:__subpackages__"]),
                ),
            ] + [
                render.call(
                    rule = "config_setting",
                    name = repr("is_{}".format(os_arch)),
                    constraint_values = render.list(constraint_values),
                    visibility = render.list(["//visibility:private"]),
                )
                for os_arch, constraint_values in constraints.items()
            ],
        ),
    )

_uv_hub = repository_rule(
    implementation = _impl,
    attrs = {
        "filenames": attr.string_list(mandatory = True),
        "hub_name": attr.string(mandatory = True),
    },
    doc = "A hub repository for exposing the tool internally",
)

def _impl_host(rctx):
    arch = _get_cpu(rctx.os.arch)
    os = _get_os(rctx.os.name)
    os_arch = "{}_{}".format(os, arch)

    target = Label("@@{}_{}//:{}".format(
        rctx.name[:-len("_host")],
        os_arch,
        "uv" if "windows" not in os_arch else "uv.exe",
    ))
    rctx.symlink(target, "uv")
    rctx.file(
        "BUILD.bazel",
        render.call(
            rule = "exports_files",
            srcs = render.list(["uv"]),
            visibility = render.list([
                "@{}//:__subpackages__".format(rctx.attr.hub_name),
            ]),
        ),
    )

_uv_host = repository_rule(
    implementation = _impl_host,
    attrs = {
        "filenames": attr.string_list(mandatory = True),
        "hub_name": attr.string(mandatory = True),
    },
    doc = "A hub repository for exposing the tool internally",
)

def _uv_archive(hub_name, file, url, sha256):
    """uv_archive creates a spoke repo for the uv hub repo."""
    if url.endswith(".tar.gz"):
        strip_prefix = file[:-len(".tar.gz")]
    else:
        strip_prefix = None

    cpu = _get_cpu(file)
    os = _get_os(file)
    name = "{}_{}_{}".format(hub_name, os, cpu)

    http_archive(
        name = name,
        url = url,
        sha256 = sha256,
        strip_prefix = strip_prefix,
        build_file_content = render.call(
            rule = "exports_files",
            srcs = """glob(["*"])""",
            visibility = render.list([
                "@{}//:__subpackages__".format(hub_name),
            ]),
        ),
    )

def uv_hub(name, filenames, urls, add_host_hub = False):
    """Create a uv hub repository for using the tool in rules.

    Args:
        name: str, the name of the hub repo.
        filenames: dict[str, str], the map from filename to sha256 of the filename.
        urls: dict[str, str], the map from filename to its url.
        add_host_hub: bool, a boolean controlling if a repo name "{name}_host"
            is created. This could be useful in using the uv binary in repository
            rules in the `pip.parse` extension.

    Returns:
        The list of repos that should be publicly used
    """
    for file, want_sha256 in filenames.items():
        _uv_archive(
            hub_name = name,
            file = file,
            url = urls[file],
            sha256 = want_sha256,
        )

    _uv_hub(
        name = name,
        hub_name = name,
        filenames = filenames.keys(),
    )
    repos = [name]

    if add_host_hub:
        # This could allow uv to be used in the `pip.parse` extension
        _uv_host(
            name = name + "_host",
            hub_name = name,
            filenames = filenames.keys(),
        )
        repos.append(name + "_host")

    return repos
