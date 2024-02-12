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

load("//python/config_settings:config_settings.bzl", "VERSION_FLAG_VALUES")
load("//python/private:render_pkg_aliases.bzl", "render_pkg_aliases")
load("//python/private:text_util.bzl", "render")
load("//python/private:whl_target_platforms.bzl", "whl_target_platforms")
load(":utils.bzl", "whl_map_decode")

_BUILD_FILE_CONTENTS = """\
load("@@{rules_python}//python/config_settings:config_settings.bzl", "is_python_config_setting")
package(default_visibility = ["//visibility:public"])

# Ensure the `requirements.bzl` source can be accessed by stardoc, since users load() from it
exports_files(["requirements.bzl"])
"""

_python_version = str(Label("//python/config_settings:python_version"))

def _pip_repository_impl(rctx):
    bzl_packages = rctx.attr.whl_map.keys()
    whl_map = whl_map_decode(rctx.attr.whl_map)
    aliases = render_pkg_aliases(
        repo_name = None,
        rules_python = rctx.attr._template.workspace_name,
        default_version = rctx.attr.default_version,
        whl_map = whl_map,
    )
    for path, contents in aliases.items():
        rctx.file(path, contents)

    # NOTE: we are using the canonical name with the double '@' in order to
    # always uniquely identify a repository, as the labels are being passed as
    # a string and the resolution of the label happens at the call-site of the
    # `requirement`, et al. macros.
    macro_tmpl = "@@{name}//{{}}:{{}}".format(name = rctx.attr.name)

    rctx.file("BUILD.bazel", "\n\n".join(
        [
            _BUILD_FILE_CONTENTS.format(rules_python = rctx.attr._template.workspace_name),
            _render_config_settings(
                whl_map = whl_map,
                rules_python = rctx.attr._template.workspace_name,
            ),
        ],
    ))
    rctx.template("requirements.bzl", rctx.attr._template, substitutions = {
        "%%ALL_DATA_REQUIREMENTS%%": render.list([
            macro_tmpl.format(p, "data")
            for p in bzl_packages
        ]),
        "%%ALL_REQUIREMENTS%%": render.list([
            macro_tmpl.format(p, p)
            for p in bzl_packages
        ]),
        "%%ALL_WHL_REQUIREMENTS_BY_PACKAGE%%": render.dict({
            p: macro_tmpl.format(p, "whl")
            for p in bzl_packages
        }),
        "%%MACRO_TMPL%%": macro_tmpl,
        "%%NAME%%": rctx.attr.repo_name,
    })

def _render_config_settings(*, whl_map, rules_python):
    platforms = {}
    for infos in whl_map.values():
        for info in infos:
            name_tmpl = "is_python_{version}"
            constraint_values = []

            # TODO @aignas 2024-02-12: improve this by passing the list of target platforms to the macro instead
            if info.platform:
                ps = whl_target_platforms(info.platform)

                if len(ps) != 1:
                    fail("the 'platform' must yield a single target platform. Did you try to use macosx_x_y_universal2?")

                name_tmpl = "{}_{}_{}".format(name_tmpl, ps[0].os, ps[0].cpu)

                constraint_values = [
                    "@platforms//os:{}".format(ps[0].os),
                    "@platforms//cpu:{}".format(ps[0].cpu),
                ]

            name = name_tmpl.format(version = info.version)
            if name in platforms:
                continue

            platforms[name] = dict(
                name = name,
                flag_values = {
                    _python_version: info.version,
                },
                constraint_values = constraint_values,
                match_extra = {
                    name_tmpl.format(version = micro): {_python_version: micro}
                    for micro in VERSION_FLAG_VALUES[info.version]
                },
                # Visibile only within the hub repo
                visibility = ["//:__subpackages__"],
            )

    return "\n\n".join([
        render.is_python_config_setting(**kwargs) if kwargs.get("constraint_values") else render.alias(
            name = kwargs["name"],
            actual = repr("@@{rules_python}//python/config_settings:{name}".format(
                rules_python = rules_python,
                name = kwargs["name"],
            )),
            visibility = kwargs.get("visibility"),
        )
        for kwargs in platforms.values()
    ])

pip_repository_attrs = {
    "default_version": attr.string(
        mandatory = True,
        doc = """\
This is the default python version in the format of X.Y. This should match
what is setup by the 'python' extension using the 'is_default = True'
setting.""",
    ),
    "repo_name": attr.string(
        mandatory = True,
        doc = "The apparent name of the repo. This is needed because in bzlmod, the name attribute becomes the canonical name.",
    ),
    "whl_map": attr.string_dict(
        mandatory = True,
        doc = "The wheel map where values are python versions",
    ),
    "_template": attr.label(
        default = ":requirements.bzl.tmpl",
    ),
}

pip_repository = repository_rule(
    attrs = pip_repository_attrs,
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _pip_repository_impl,
)
