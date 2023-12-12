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

## Notes on the approach above

Pros:
* Really fast, no need to re-download the wheels when changing the contents of
  `whl_library`.
Cons:
* The sha256 files in filenames makes things difficult to read/understand.
* The cyclic dependency groups need extra work as the visibility between targets needs
  to be ironed out.
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
  * additive_build_content => What to do?
  * copy_files => Apply to each platform-specific wheel and it will be OK and we will nede to generate aliases for them in the minihub.
  * copy_executables => Apply to each platform-specific wheel and it will be OK and we will need to generate aliases for them in the minihub.
  * data => Apply to each platform-specific wheel and it will be OK.
  * data_exclude_glob => Apply to each platform-specific wheel and it will be OK.
  * srcs_exclude_glob => Apply to each platform-specific wheel and it will be OK.

## Notes on this approach

* We need to define the `whl_lock` and related repos in a separate bzlmod
  extension. This is not something we want, because we increase the API scope
  which is not desirable.

"""

load("//python:versions.bzl", "WINDOWS_NAME")
load("//python/pip_install:pip_repository.bzl", _whl_library = "whl_library")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")
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
load("//python/private:toolchains_repo.bzl", "get_host_os_arch")
load("//python/private:patch_whl.bzl", "patch_whl")
load("//python/private:text_util.bzl", "render")
load(":label.bzl", _label = "label")

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

def whl_library(name, requirement, **kwargs):
    """Generate a number of third party repos for a particular wheel.
    """
    sha256s = [sha.strip() for sha in requirement.split("--hash=sha256:")[1:]]

    distribution, _, _ = requirement.partition("==")
    distribution, _, _ = distribution.partition("[")
    distribution = normalize_name(distribution)

    metadata = _label("@{}_metadata//:files.json".format(distribution))

    whl_minihub(
        name = name,
        repo = kwargs.get("repo"),
        group_name = kwargs.get("group_name"),
        distribution = distribution,
        sha256s = sha256s,
        metadata = metadata,
    )

    whl_patches = kwargs.pop("whl_patches", None)

    for sha256 in sha256s:
        whl_name = "{}_{}".format(name, sha256[:6])

        # We would use http_file, but we are passing the URL to use via a file,
        # if the url is known (in case of using pdm lock), we could use an
        # http_file.
        whl_archive(
            name = whl_name + "_whl",
            metadata = metadata,
            sha256 = sha256,
            whl_patches = whl_patches,
            # TODO @aignas 2023-12-12: do patching of the wheel here
        )

        _whl_library(
            name = whl_name,
            file = _label("@{}_whl//:whl".format(whl_name)),
            requirement = requirement,
            **kwargs
        )

def _whl_minihub_impl(rctx):
    metadata = rctx.path(rctx.attr.metadata)
    files = json.decode(rctx.read(metadata))

    abi = "cp" + rctx.attr.repo.rpartition("_")[2]

    build_contents = []
    sha256s = {sha: True for sha in rctx.attr.sha256s}

    actual = None
    select = {}
    for file in files["files"]:
        sha256 = file["sha256"]
        if sha256 not in sha256s:
            continue

        tmpl = "@{name}_{distribution}_{sha256}//:{{target}}".format(
            name = rctx.attr.repo,
            distribution = rctx.attr.distribution,
            sha256 = sha256[:6],
        )

        _, _, filename = file["url"].strip().rpartition("/")
        if not filename.endswith(".whl"):
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

    build_contents += [
        render.alias(
            name = target,
            actual = actual.format(target = target) if actual else render.select({k: v.format(target = target) for k, v in select.items()}),
            visibility = [visibility],
        )
        for target, visibility in {
            DATA_LABEL: "//visibility:public",
            DIST_INFO_LABEL: "//visibility:public",
            PY_LIBRARY_IMPL_LABEL: impl_vis,
            WHEEL_FILE_IMPL_LABEL: impl_vis,
        }.items()
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
        "distribution": attr.string(mandatory = True),
        "group_name": attr.string(),
        "metadata": attr.label(mandatory = True, allow_single_file = True),
        "repo": attr.string(mandatory = True),
        "sha256s": attr.string_list(mandatory = True),
    },
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _whl_minihub_impl,
)

def _whl_archive_impl(rctx):
    prefix, _, _ = rctx.attr.name.rpartition("_")
    prefix, _, _ = prefix.rpartition("_")

    metadata = rctx.path(rctx.attr.metadata)
    files = json.decode(rctx.read(metadata))
    sha256 = rctx.attr.sha256
    url = None
    for file in files["files"]:
        if file["sha256"] == sha256:
            url = file["url"]
            break

    if url == None:
        fail("Could not find a file with sha256 '{}' within: {}".format(sha256, files))

    _, _, filename = url.rpartition("/")
    filename = filename.strip()
    result = rctx.download(url, output = filename, sha256 = sha256)
    if not result.success:
        fail(result)

    whl_path = rctx.path(filename)

    if rctx.attr.whl_patches:
        patches = {}
        for patch_file, json_args in rctx.attr.whl_patches.items():
            patch_dst = struct(**json.decode(json_args))
            if whl_path.basename in patch_dst.whls:
                patches[patch_file] = patch_dst.patch_strip


        whl_path = patch_whl(
            rctx,
            # TODO @aignas 2023-12-12: do not use system Python
            python_interpreter = _resolve_python_interpreter(rctx),
            whl_path = whl_path,
            patches = patches,
            quiet = rctx.attr.quiet,
            timeout = rctx.attr.timeout,
        )

    rctx.symlink(whl_path, "whl")

    rctx.file(
        "BUILD.bazel",
        """\
filegroup(
    name="whl",
    srcs=["{filename}"],
    visibility=["//visibility:public"],
)
""".format(filename = whl_path.basename),
    )

whl_archive = repository_rule(
    attrs = {
        "metadata": attr.label(mandatory = True, allow_single_file = True),
        "quiet": attr.bool(default=True),
        "sha256": attr.string(mandatory = False),
        "timeout": attr.int(default=60),
        "whl_patches": attr.label_keyed_string_dict(
            doc = """"a label-keyed-string dict that has
                json.encode(struct([whl_file], patch_strip]) as values. This
                is to maintain flexibility and correct bzlmod extension interface
                until we have a better way to define whl_library and move whl
                patching to a separate place. INTERNAL USE ONLY.""",
        ),
        "python_interpreter": attr.string(),
        "python_interpreter_target": attr.label(),
    },
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _whl_archive_impl,
)

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
        python_interpreter = rctx.path(rctx.attr.python_interpreter_target)

        if BZLMOD_ENABLED:
            (os, _) = get_host_os_arch(rctx)

            # On Windows, the symlink doesn't work because Windows attempts to find
            # Python DLLs where the symlink is, not where the symlink points.
            if os == WINDOWS_NAME:
                python_interpreter = python_interpreter.realpath
    elif "/" not in python_interpreter:
        found_python_interpreter = rctx.which(python_interpreter)
        if not found_python_interpreter:
            fail("python interpreter `{}` not found in PATH".format(python_interpreter))
        python_interpreter = found_python_interpreter
    return python_interpreter
