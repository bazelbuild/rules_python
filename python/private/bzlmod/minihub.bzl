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

"""The overall design is:

There is a single Pip hub repository, which creates the following repos:
* `whl_index` that downloads the SimpleAPI page for a particular package
  from the given indexes. It creates labels with URLs that can be used
  to download things. Args:
  * distribution - The name of the distribution.
  * version - The version of the package.
* `whl_archive` that downloads a particular wheel for a package, it accepts
  the following args:
  * sha256 - The sha256 to download.
  * url - The url to use. Optional.
  * url_file - The label that has the URL for downloading the wheel. Optional.
    Mutually exclusive with the url arg.
  * indexes - Indexes to query. Optional.
* `whl_library` that extracts a particular wheel.

This is created to make use of the parallelism that can be achieved if fetching
is done in separate threads, one for each external repository.
"""

load("//python/pip_install:pip_repository.bzl", _whl_library = "whl_library")
load("//python/private:parse_whl_name.bzl", "parse_whl_name")
load("//python/private:text_util.bzl", "render")

_this = str(Label("//:unknown"))

def _label(label):
    """This function allows us to construct labels to pass to rules."""
    prefix, _, _ = _this.partition("//")
    prefix = prefix + "~pip~"
    return Label(label.replace("@", prefix))

_os_in_tag = {
    "linux": "linux",
    "macosx": "osx",
    "manylinux": "linux",
    "musllinux": "linux",
    "win": "windows",
}

_cpu_in_tag = {
    "aarch64": "aarch64",
    "amd64": "x86_64",
    "arm64": "aarch64",
    "i386": "x86_32",
    "i686": "x86_32",
    "ppc64le": "ppc",
    "s390x": "s390x",
    "win32": "x86_32",
    "x86_64": "x86_64",
}

def _parse_os_from_tag(platform_tag):
    for prefix, os in _os_in_tag.items():
        if platform_tag.startswith(prefix):
            return os

    fail("cannot get os from platform tag: {}".format(platform_tag))

def _parse_cpu_from_tag(platform_tag):
    if "universal2" in platform_tag:
        return ("x86_64", "aarch64")

    for suffix, cpu in _cpu_in_tag.items():
        if platform_tag.endswith(suffix):
            return (cpu,)

    fail("cannot get cpu from platform tag: {}".format(platform_tag))

def _parse_platform_tag(platform_tag):
    os = _parse_os_from_tag(platform_tag)

    cpu = _parse_cpu_from_tag(platform_tag)
    return os, cpu

def whl_library(name, distribution, requirement, repo, **kwargs):
    """Generate a number of third party repos for a particular wheel.
    """
    indexes = kwargs.get("indexes", ["https://pypi.org/simple"])
    sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]

    # Defines targets:
    # * whl - depending on the platform, return the correct whl defined in "name_sha.whl"
    # * pkg - depending on the platform, return the correct py_library target in "name_sha"
    # * dist_info - depending on the platform, return the correct py_library target in "name_sha"
    # * data - depending on the platform, return the correct py_library target in "name_sha"
    #
    # Needs:
    # * Select on the Python interpreter version
    # * Select on the glibc/musllibc or ask the user to provide whether they want musllibc or glibc at init
    # * Select on the platform
    whl_index(
        name = name,
        distribution = distribution,
        sha256s = sha256s,
        indexes = indexes,
        repo = repo,
    )

    for sha256 in sha256s:
        whl_repo = "{}_{}_whl".format(name, sha256)

        # We would use http_file, but we are passing the URL to use via a file,
        # if the url is known (in case of using pdm lock), we could use an
        # http_file.
        whl_archive(
            name = whl_repo,
            url_file = _label("@{}//urls:{}".format(name, sha256)),
            sha256 = sha256,
        )

        _whl_library(
            name = "{name}_{sha256}".format(name = name, sha256 = sha256),
            file = _label("@{}//:whl".format(whl_repo)),
            requirement = requirement,  # do we need this?
            repo = repo,
            **kwargs
        )

def _whl_index_impl(rctx):
    files = []
    want_shas = {sha: True for sha in rctx.attr.sha256s}
    for i, index_url in enumerate(rctx.attr.indexes):
        html = "index-{}.html".format(i)
        result = rctx.download(
            url = index_url + "/" + rctx.attr.distribution,
            output = html,
        )
        if not result.success:
            fail(result)

        contents = rctx.read(html)
        rctx.delete(html)

        _, _, hrefs = contents.partition("<a href=\"")
        for line in hrefs.split("<a href=\""):
            url, _, tail = line.partition("#")
            _, _, tail = tail.partition("=")
            sha256, _, tail = tail.partition("\"")
            if sha256 not in want_shas:
                continue

            files.append(struct(
                url = url,
                sha256 = sha256,
            ))

    if not files:
        fail("Could not find any files for: {}".format(rctx.attr.distribution))

    for file in files:
        contents = json.encode(file)
        rctx.file("urls/{}".format(file.sha256), contents)

    rctx.file("urls/BUILD.bazel", """exports_files(glob(["*"]), visibility={})""".format(
        render.list([
            "@@{}_{}_whl//:__pkg__".format(rctx.attr.name, file.sha256)
            for file in files
        ]),
    ))

    abi = "cp" + rctx.attr.repo.rpartition("_")[2]

    build_contents = []

    actual = None
    select = {}
    for file in files:
        tmpl = "@{name}_{distribution}_{sha256}//:{{target}}".format(
            name = rctx.attr.repo,
            distribution = rctx.attr.distribution,
            sha256 = file.sha256,
        )

        _, _, filename = file.url.strip().rpartition("/")
        if not filename.endswith(".whl"):
            select["//conditions:default"] = tmpl
            continue

        whl = parse_whl_name(filename)
        if "py3" in whl.python_tag.split("."):
            select["//conditions:default"] = tmpl
            break

        if abi != whl.abi_tag:
            continue

        os, cpus = _parse_platform_tag(whl.platform_tag)

        for cpu in cpus:
            platform = "is_{}_{}".format(os, cpu)
            select[":" + platform] = tmpl

            config_setting = """\
config_setting(
    name = "{platform}",
    constraint_values = [
        "@platforms//cpu:{cpu}",
        "@platforms//os:{os}",
    ],
    visibility = ["//visibility:private"],
)""".format(platform = platform, cpu = cpu, os = os)
            if config_setting not in build_contents:
                build_contents.append(config_setting)

    if len(select) == 1 and "//conditions:default" in select:
        actual = repr(select["//conditions:default"])

    build_contents += [
        render.alias(
            name = target,
            actual = actual.format(target = target) if actual else render.select({k: v.format(target = target) for k, v in select.items()}),
            visibility = ["//visibility:public"],
        )
        for target in ["pkg", "whl", "data", "dist_info", "_whl", "_pkg"]
    ]

    rctx.file("BUILD.bazel", "\n\n".join(build_contents))

whl_index = repository_rule(
    attrs = {
        "distribution": attr.string(mandatory = True),
        "indexes": attr.string_list(mandatory = True),
        "repo": attr.string(mandatory = True),
        "sha256s": attr.string_list(mandatory = True),
    },
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _whl_index_impl,
)

def _whl_archive_impl(rctx):
    prefix, _, _ = rctx.attr.name.rpartition("_")
    prefix, _, _ = prefix.rpartition("_")

    # TODO @aignas 2023-12-09:  solve this without restarts
    url_file = rctx.path(rctx.attr.url_file)
    url = json.decode(rctx.read(url_file))["url"]

    _, _, filename = url.rpartition("/")
    filename = filename.strip()
    result = rctx.download(url, output = filename, sha256 = rctx.attr.sha256)
    if not result.success:
        fail(result)

    rctx.symlink(filename, "whl")

    rctx.file(
        "BUILD.bazel",
        """\
filegroup(
    name="whl",
    srcs=["{filename}"],
    visibility=["//visibility:public"],
)
""".format(filename = filename),
    )

whl_archive = repository_rule(
    attrs = {
        "sha256": attr.string(mandatory = False),
        "url_file": attr.label(mandatory = True),
    },
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _whl_archive_impl,
)
