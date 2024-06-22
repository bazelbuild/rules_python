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

load("//python/private:text_util.bzl", "render")
load(
    "//python/private/pypi:render_pkg_aliases.bzl",
    "render_multiplatform_pkg_aliases",
    "whl_alias",
)

_BUILD_FILE_CONTENTS = """\
package(default_visibility = ["//visibility:public"])

# Ensure the `requirements.bzl` source can be accessed by stardoc, since users load() from it
exports_files(["requirements.bzl"])
"""

def _pip_repository_impl(rctx):
    bzl_packages = rctx.attr.whl_map.keys()
    aliases = render_multiplatform_pkg_aliases(
        aliases = {
            key: [whl_alias(**v) for v in json.decode(values)]
            for key, values in rctx.attr.whl_map.items()
        },
        default_version = rctx.attr.default_version,
        default_config_setting = "//_config:is_python_" + rctx.attr.default_version,
        requirement_cycles = rctx.attr.groups,
    )
    for path, contents in aliases.items():
        rctx.file(path, contents)

    # NOTE: we are using the canonical name with the double '@' in order to
    # always uniquely identify a repository, as the labels are being passed as
    # a string and the resolution of the label happens at the call-site of the
    # `requirement`, et al. macros.
    macro_tmpl = "@@{name}//{{}}:{{}}".format(name = rctx.attr.name)

    rctx.file("BUILD.bazel", _BUILD_FILE_CONTENTS)
    rctx.template("requirements.bzl", rctx.attr._template, substitutions = {
        "%%ALL_DATA_REQUIREMENTS%%": render.list([
            macro_tmpl.format(p, "data")
            for p in bzl_packages
        ]),
        "%%ALL_REQUIREMENTS%%": render.list([
            macro_tmpl.format(p, "pkg")
            for p in bzl_packages
        ]),
        "%%ALL_WHL_REQUIREMENTS_BY_PACKAGE%%": render.dict({
            p: macro_tmpl.format(p, "whl")
            for p in bzl_packages
        }),
        "%%MACRO_TMPL%%": macro_tmpl,
        "%%NAME%%": rctx.attr.repo_name,
    })

pip_repository_attrs = {
    "default_version": attr.string(
        mandatory = True,
        doc = """\
This is the default python version in the format of X.Y. This should match
what is setup by the 'python' extension using the 'is_default = True'
setting.""",
    ),
    "groups": attr.string_list_dict(
        mandatory = False,
    ),
    "repo_name": attr.string(
        mandatory = True,
        doc = "The apparent name of the repo. This is needed because in bzlmod, the name attribute becomes the canonical name.",
    ),
    "whl_map": attr.string_dict(
        mandatory = True,
        doc = """\
The wheel map where values are json.encoded strings of the whl_map constructed
in the pip.parse tag class.
""",
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
