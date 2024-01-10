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

"""This stores the `bzlmod` specific `multiarch_whl_library` that can make more
assumptions about how the repositories are setup and we can also fetch some data
from the PyPI via its simple API.

There is a single `multiarch_whl_library` repository that only does aliases by
target platform to the available whls and/or the whl built from sdist by bazel.
The main algorithm is as below:
1. Fetch data from all known PyPI indexes about where the wheels live.
2. Ensure that we have found info about all of the packages by checking that we know
   URL for each artifact that is mentioned by its sha256 in the requirements file.
3. Infer the compatible platforms for the artifacts by parsing the last entry
   in the URL. This allows us to create a set of `whl_library` repos that (mostly)
   do not depend on the host platform.

Shortcomings of the design:
- We need to wait for the module extension to pull metadata about existing packgaes
  for multiple distributions and it scales as 'number of different packgaes' x
  'number of indexes'. We do some optimizations that make the scaling better,
  but without `MODULE.bazel.lock` we need to do this every time if we haven't
  cached the repositories.

- whl annotation API may further break user workflows because the targets added
  via `additive_build_content` is not added to the `pip_XY_foo` but rather to
  `pip_XY_foo__plat` which suggests that we should have some way to tell the
  `hub` repo to expose extra alias targets.

  The `additive_build_content`, `copy_files` and `copy_files` are applied to each
  extracted `whl` but not exposed to the user via extra alias definition in the hub
  repository.

  The `data`, `data_exclude_glob` and `srcs_exclude_glob` are all forwarded to the
  definition of the `py_library` target as expected.

- The cyclic dependencies can-not be automatically resolved yet and we need to fetch
  additional whl metadata unless we have the METADATA parsing in fewer places.

- For now, the wheels are potentially extracted multiple times, but this could be
  possible to improve if we unify selecting based on the target platform and python
  version into a single `config_setting`.

Benefits of the design:
- Really fast to iterate as the whls do not need to be re-downloaded if the
  sha256 and the whl URL does not change.

- We can use the same downloaded wheel in multiple `whl_library` instances that
  are for different Python versions.

- The dependency closures are still isolated making this a relatively safe change
  from the traditional `whl_library`.

- This could be extended very easily to consume `poetry.lock` or `pdm.lock` files.

- We can build `rules_oci` images without needed extra work if the `sdists` are for
  pure Python `whls` without any extra effort or needing to specify `download = True`.

- We can download the Simple API contents in parallel with changes landed for 7.1.0.
"""

load("//python/pip_install:pip_repository.bzl", "whl_library")
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
load("//python/private:whl_target_platforms.bzl", "whl_target_platforms")

def multiarch_whl_library(name, *, requirement_by_os, files, extra_pip_args, **kwargs):
    """Generate a number of third party repos for a particular wheel.

    Args:
        name(str): the name of the apparent repo that does the select on the target platform.
        requirement_by_os(dict[str]): the requirement_by_os line that this repo corresponds to.
        files(dict[str, PyPISource]): the list of file labels
        extra_pip_args(list[str]): The pip args by platform.
        **kwargs: extra arguments passed to the underlying `whl_library` repository rule.
    """
    needed_shas = {}
    for os, requirement in requirement_by_os.items():
        if os == "host":
            continue

        for sha in requirement.split("--hash=sha256:")[1:]:
            sha = sha.strip()
            if sha not in needed_shas:
                needed_shas[sha] = []

            needed_shas[sha].append(os)

    needed_files = {
        files.files[sha]: plats
        for sha, plats in needed_shas.items()
    }
    _, _, want_abi = kwargs.get("repo").rpartition("_")

    # TODO @aignas 2023-12-20: how can we get the ABI that we need for this particular repo? It would be better to not need to resolve it and just add it to the `target_platforms` list for the user to provide.
    want_abi = "cp" + want_abi
    files = {}
    for f, oses in needed_files.items():
        if not f.filename.endswith(".whl"):
            files["sdist"] = (f, requirement_by_os["host"])
            continue

        parsed = parse_whl_name(f.filename)

        if "musl" in parsed.platform_tag:
            # TODO @aignas 2023-12-21: musl wheels are currently unsupported, how can we allow the user to control this? Maybe by target platforms?
            continue

        if parsed.abi_tag in ["none", "abi3", want_abi]:
            plat = parsed.platform_tag.split(".")[0]
            if plat == "any":
                files[plat] = (f, requirement_by_os[oses[0]])
            else:
                # this assumes that the target_platform for a whl will have the same os, which is most often correct
                target_platform = whl_target_platforms(plat)[0]
                files[plat] = (f, requirement_by_os.get(target_platform.os, requirement_by_os["default"]))

    libs = {}
    for plat, (f, r) in files.items():
        whl_name = "{}__{}".format(name, plat)
        libs[plat] = f.filename
        req, hash, _ = r.partition("--hash=sha256:")
        req = "{} {}{}".format(req.strip(), hash, f.sha256)
        whl_library(
            name = whl_name,
            experimental_whl_label = f.label,
            requirement = req,
            extra_pip_args = extra_pip_args,
            **kwargs
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

        # TODO @aignas 2023-12-20: check if we have 'download_only = True' passed
        # to the `whl_library` and then remove the `sdist` from the select and
        # add a no_match error message.
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

        for p in whl_target_platforms(whl.platform_tag):
            platform = "is_{}_{}".format(p.os, p.cpu)
            select[":" + platform] = tmpl

            config_setting = """\
config_setting(
    name = "{platform}",
    constraint_values = [
        "@platforms//cpu:{cpu}",
        "@platforms//os:{os}",
    ],
    visibility = ["//visibility:private"],
)""".format(platform = platform, cpu = p.cpu, os = p.os)
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
