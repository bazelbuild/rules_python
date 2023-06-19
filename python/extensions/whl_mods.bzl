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

"Module extension that creates different whl modifications used when we generate wheels."

def _whl_mods_impl(mctx):
    whl_mods_dict = {}
    for mod in mctx.modules:
        for whl_mod_attr in mod.tags.create:
            if whl_mod_attr.hub_name not in whl_mods_dict.keys():
                whl_mods_dict[whl_mod_attr.hub_name] = {whl_mod_attr.whl_name: whl_mod_attr}
            elif whl_mod_attr.whl_name in whl_mods_dict[whl_mod_attr.hub_name].keys():
                fail("Found same whl_name in the same hub, please use a different hub_name")
            else:
                whl_mods_dict[whl_mod_attr.hub_name][whl_mod_attr.whl_name] = whl_mod_attr

    for hub_name, whl_maps in whl_mods_dict.items():
        whl_mods = {}
        for whl_name, mods in whl_maps.items():
            whl_mods[whl_name] = json.encode(struct(
                additive_build_content = mods.additive_build_content,
                copy_files = mods.copy_files,
                copy_executables = mods.copy_executables,
                data = mods.data,
                data_exclude_glob = mods.data_exclude_glob,
                srcs_exclude_glob = mods.srcs_exclude_glob,
            ))

        _whl_mods_repo(
            name = hub_name,
            whl_mods = whl_mods,
        )

whl_modifications = module_extension(
    doc = """\
""",
    implementation = _whl_mods_impl,
    tag_classes = {
        "create": tag_class(
            attrs = {
                "additive_build_content": attr.string(
                    doc = "(str, optional): Raw text to add to the generated `BUILD` file of a package.",
                ),
                "additive_build_content_file": attr.string(
                    doc = """\
(str, optional): path to a BUILD file to add to the generated
`BUILD` file of a package.""",
                ),
                "copy_files": attr.string_dict(
                    doc = """\
(dict, optional): A mapping of `src` and `out` files for 
[@bazel_skylib//rules:copy_file.bzl][cf]""",
                ),
                "copy_executables": attr.string_dict(
                    doc = """\
(dict, optional): A mapping of `src` and `out` files for
[@bazel_skylib//rules:copy_file.bzl][cf]. Targets generated here will also be flagged as
executable.""",
                ),
                "data": attr.string_list(
                    doc = """\
(list, optional): A list of labels to add as `data` dependencies to
the generated `py_library` target.""",
                ),
                "data_exclude_glob": attr.string_list(
                    doc = """\
(list, optional): A list of exclude glob patterns to add as `data` to
the generated `py_library` target.""",
                ),
                "hub_name": attr.string(
                    doc = """\
Name of the whl modification, hub we use this name to set the modifications for
pip.parse. If you have different pip hubs you can use a different name,
otherwise it is best practice to just use one.""",
                    mandatory = True,
                ),
                "srcs_exclude_glob": attr.string_list(
                    doc = """\
(list, optional): A list of labels to add as `srcs` to the generated
`py_library` target.""",
                ),
                "whl_name": attr.string(
                    doc = "The whl name that the modifications are used for",
                    mandatory = True,
                ),
            },
        ),
    },
)

def _whl_mods_repo_impl(rctx):
    rctx.file("BUILD.bazel", """\
exports_files(
    glob(["*.json"]),
    visibility = ["//visibility:public"],
)
""")

    for whl_name, mods in rctx.attr.whl_mods.items():
        rctx.file("{}.json".format(whl_name), mods)

_whl_mods_repo = repository_rule(
    doc = """\
""",
    implementation = _whl_mods_repo_impl,
    attrs = {
        "whl_mods": attr.string_dict(
            mandatory = True,
            doc = "JSON endcoded string that is provided to wheel_builder.py",
        ),
    },
)
