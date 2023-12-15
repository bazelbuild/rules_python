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

# Attempt 1

There is a single Pip hub repository, which creates the following repos:
* `whl_index` that downloads the SimpleAPI page for a particular package
  from the given indexes. It creates labels with URLs that can be used
  to download things. Args:
  * distribution - The name of the distribution.
  * version - The version of the package.
* `pypi_archive` that downloads a particular wheel for a package, it accepts
  the following args:
  * sha256 - The sha256 to download.
  * url - The url to use. Optional.
  * url_file - The label that has the URL for downloading the wheel. Optional.
    Mutually exclusive with the url arg.
  * indexes - Indexes to query. Optional.
* `whl_library` that extracts a particular wheel.

This is created to make use of the parallelism that can be achieved if fetching
is done in separate threads, one for each external repository.

## Notes on the approach above

Pros:
* Really fast, no need to re-download the wheels when changing the contents of
  `whl_library`.
* The cyclic dependency groups just work with a few tweaks.
Cons:
* The sha256 files in filenames makes things difficult to read/understand.
* The whl_annotations break, because users would need to specify weird repos in
  their `use_repo` statements in the `MODULE.bazel` in order to make the
  annotations useful. The need for forwarding the aliases based on the
  annotations is real.
* The index would be different for different lock files.

# Approach 2

* In case we use requirements:
    * `pypi_metadata` spoke repo that exposes the following for each distribution name:
      `metadata.json - contains shas and filenames
    * `pypi_metadata` hub repo that has aliases for all repos in one place,
      helps with label generation/visibility.
    * `whl_lock` hub repo that uses labels from `pypi_metadata` hub to generate a
      single lock file: `lock.json`.
* In case we use `pdm` or `poetry` or `hatch` lock files:
    * `whl_lock` repo that translates the file into `lock.json`.
* `pip.bzl` extension materializes the `whl_lock//:lock.json` file and defines the `whl_library` repos:
    * For each whl name that we are interested in, create a `http_file` repo for the wheel.
    * Generate a `whl_library` by passing a `file` argument to the `http_file`.
    * If the whl is multi-platform - whl_library minihub does not need to be created.
    * If the whl is platform-specific - whl_library minihub needs to be created.

Pros:
* Solves `sha256` not being in repo names
* Lock format can be the same for all
* We may include whl metadata in the lock which means that we may have the dep graph
  before creating the `whl_libraries`. If we have that, we can generate the cyclic dependency groups procedurally.
Cons:
* cyclic dependency groups for platform-specific wheels need a different approach than
  what we have today.
* whl_annotations for platform-specific wheels could be worked arround only in a subset
  of cases. This is the analysis for each field:
  - [ ] additive_build_content => What to do?
  - [.] copy_files => Apply to each platform-specific wheel and it will be OK and we will nede to generate aliases for them in the minihub.
  - [.] copy_executables => Apply to each platform-specific wheel and it will be OK and we will need to generate aliases for them in the minihub.
  - [x] data => Apply to each platform-specific wheel and it will be OK.
  - [x] data_exclude_glob => Apply to each platform-specific wheel and it will be OK.
  - [x] srcs_exclude_glob => Apply to each platform-specific wheel and it will be OK.

## Notes on this approach

* We need to define the `whl_lock` and related repos in a separate bzlmod
  extension. This is not something we want, because we increase the API scope
  which is not desirable.

"""

load("//python/pip_install:pip_repository.bzl", _whl_library = "whl_library")
load(
    "//python/private:labels.bzl",
    "DATA_LABEL",
    "DIST_INFO_LABEL",
    "PY_LIBRARY_IMPL_LABEL",
    "PY_LIBRARY_PUBLIC_LABEL",
    "WHEEL_FILE_IMPL_LABEL",
    "WHEEL_FILE_PUBLIC_LABEL",
)
load("//python/private:normalize_name.bzl", "normalize_name")
load("//python/private:parse_whl_name.bzl", "parse_whl_name")
load("//python/private:text_util.bzl", "render")

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

def whl_library(name, *, requirement, files, **kwargs):
    """Generate a number of third party repos for a particular wheel.
    """
    distribution = files.distribution
    needed_files = [
        files.files[sha.strip()] for sha in requirement.split("--hash=sha256:")[1:]
    ]
    _, _, want_abi = kwargs.get("repo").rpartition("_")
    want_abi = "cp" + want_abi
    files = {}
    for f in needed_files:
        if not f.filename.endswith(".whl"):
            files["sdist"] = f
            continue

        parsed = parse_whl_name(f.filename)

        if "musl" in parsed.platform_tag:
            # currently unsupported
            continue

        if parsed.abi_tag in ["none", "abi3", want_abi]:
            plat = parsed.platform_tag.split(".")[0]
            files[plat] = f

    libs = {}
    for plat, f in files.items():
        whl_name = "{}__{}".format(name, plat)
        libs[plat] = f.filename
        _whl_library(
            name = whl_name,
            file = f.label,
            requirement = requirement,
            **kwargs,
        )

    whl_minihub(
        name = name,
        repo = kwargs.get("repo"),
        group_name = kwargs.get("group_name"),
        libs = libs,
        annotation = kwargs.get("annotation"),
    )

def _whl_minihub_impl(rctx):
    abi = "cp" + rctx.attr.repo.rpartition("_")[2]
    _, repo, suffix = rctx.attr.name.rpartition(rctx.attr.repo)
    prefix = repo + suffix

    build_contents = []

    actual = None
    select = {}
    for plat, filename in rctx.attr.libs.items():
        tmpl = "@{}__{}//:{{target}}".format(prefix, plat)

        if plat == "sdist":
            select["//conditions:default"] = tmpl
            continue

        whl = parse_whl_name(filename)

        # prefer 'abi3' over 'py3'?
        if "py3" in whl.python_tag or "abi3" in whl.python_tag:
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

    select = {k: v for k, v in sorted(select.items())}

    # The overall architecture:
    # * `whl_library_for_a_whl should generate only the private targets
    # * `whl_minihub` should do the `group` to `private` indirection as needed.
    #
    # then the group visibility settings remain the same.
    # then we can also set the private target visibility to something else than public
    # e.g. the _sha265 targets can only be accessed by the minihub

    group_name = rctx.attr.group_name
    if group_name:
        group_repo = rctx.attr.repo + "__groups"
        impl_vis = "@{}//:__pkg__".format(group_repo)
        library_impl_label = "@%s//:%s_%s" % (group_repo, normalize_name(group_name), "pkg")
        whl_impl_label = "@%s//:%s_%s" % (group_repo, normalize_name(group_name), "whl")
    else:
        library_impl_label = PY_LIBRARY_IMPL_LABEL
        whl_impl_label = WHEEL_FILE_IMPL_LABEL
        impl_vis = "//visibility:private"

    public_visibility = "//visibility:public"

    alias_targets = {
        DATA_LABEL: public_visibility,
        DIST_INFO_LABEL: public_visibility,
        PY_LIBRARY_IMPL_LABEL: impl_vis,
        WHEEL_FILE_IMPL_LABEL: impl_vis,
    }

    if rctx.attr.annotation:
        annotation = struct(**json.decode(rctx.read(rctx.attr.annotation)))

        for dest in annotation.copy_files.values():
            alias_targets["{}.copy".format(dest)] = public_visibility

        for dest in annotation.copy_executables.values():
            alias_targets["{}.copy".format(dest)] = public_visibility

        # FIXME @aignas 2023-12-14: is this something that we want, looks a
        # little bit hacky as we don't parse the visibility of the extra
        # targets.
        if annotation.additive_build_content:
            targets_defined_in_additional_info = [
                line.partition("=")[2].strip().strip("\"',")
                for line in annotation.additive_build_content.split("\n")
                if line.strip().startswith("name")
            ]
            for dest in targets_defined_in_additional_info:
                alias_targets[dest] = public_visibility

    build_contents += [
        render.alias(
            name = target,
            actual = actual.format(target = target) if actual else render.select({k: v.format(target = target) for k, v in select.items()}),
            visibility = [visibility],
        )
        for target, visibility in alias_targets.items()
    ]

    build_contents += [
        render.alias(
            name = target,
            actual = repr(actual),
            visibility = ["//visibility:public"],
        )
        for target, actual in {
            PY_LIBRARY_PUBLIC_LABEL: library_impl_label,
            WHEEL_FILE_PUBLIC_LABEL: whl_impl_label,
        }.items()
    ]

    rctx.file("BUILD.bazel", "\n\n".join(build_contents))

whl_minihub = repository_rule(
    attrs = {
        "annotation": attr.label(
            doc = (
                "Optional json encoded file containing annotation to apply to the extracted wheel. " +
                "See `package_annotation`"
            ),
            allow_files = True,
        ),
        "group_name": attr.string(),
        "libs": attr.string_dict(mandatory = True),
        "repo": attr.string(mandatory = True),
    },
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _whl_minihub_impl,
)
