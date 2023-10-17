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

"""Rules to generate Sphinx-compatible documentation for bzl files."""

load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("//python/private:util.bzl", "add_tag", "copy_propagating_kwargs")  # buildifier: disable=bzl-visibility

_FUNC_TEMPLATE = Label("//sphinxdocs/private:func_template.vm")
_HEADER_TEMPLATE = Label("//sphinxdocs/private:header_template.vm")
_RULE_TEMPLATE = Label("//sphinxdocs/private:rule_template.vm")
_PROVIDER_TEMPLATE = Label("//sphinxdocs/private:provider_template.vm")

def sphinx_stardocs(name, docs, footer = None, **kwargs):
    """Generate Sphinx-friendly Markdown docs using Stardoc for bzl libraries.

    A `build_test` for the docs is also generated to ensure Stardoc is able
    to process the files.

    NOTE: This generates MyST-flavored Markdown.

    Args:
        name: `str`, the name of the resulting file group with the generated docs.
        docs: `dict[str output, source]` of the bzl files to generate documentation
            for. The `output` key is the path of the output filename, e.g.,
            `foo/bar.md`. The `source` values can be either of:
            * A `str` label that points to a `bzl_library` target. The target
              name will replace `_bzl` with `.bzl` and use that as the input
              bzl file to generate docs for. The target itself provides the
              necessary dependencies.
            * A `dict` with keys `input` and `dep`. The `input` key is a string
              label to the bzl file to generate docs for. The `dep` key is a
              string label to a `bzl_library` providing the necessary dependencies.
        footer: optional [`label`] File to append to generated docs.
        **kwargs: Additional kwargs to pass onto each `sphinx_stardoc` target
    """
    add_tag(kwargs, "@rules_python//sphinxdocs:sphinx_stardocs")
    common_kwargs = copy_propagating_kwargs(kwargs)

    stardocs = []
    for out_name, entry in docs.items():
        stardoc_kwargs = {}
        stardoc_kwargs.update(kwargs)

        if types.is_string(entry):
            stardoc_kwargs["deps"] = [entry]
            stardoc_kwargs["input"] = entry.replace("_bzl", ".bzl")
        else:
            stardoc_kwargs.update(entry)
            stardoc_kwargs["deps"] = [stardoc_kwargs.pop("dep")]

        doc_name = "_{}_{}".format(name.lstrip("_"), out_name.replace("/", "_"))
        _sphinx_stardoc(
            name = doc_name,
            footer = footer,
            out = out_name,
            **stardoc_kwargs
        )
        stardocs.append(doc_name)

    native.filegroup(
        name = name,
        srcs = stardocs,
        **common_kwargs
    )
    build_test(
        name = name + "_build_test",
        targets = stardocs,
        **common_kwargs
    )

def _sphinx_stardoc(*, name, out, footer = None, public_load_path = None, **kwargs):
    if footer:
        stardoc_name = "_{}_stardoc".format(name.lstrip("_"))
        stardoc_out = "_{}_stardoc.out".format(name.lstrip("_"))
    else:
        stardoc_name = name
        stardoc_out = out

    if not public_load_path:
        public_load_path = str(kwargs["input"])

    header_name = "_{}_header".format(name.lstrip("_"))
    _expand_stardoc_template(
        name = header_name,
        template = _HEADER_TEMPLATE,
        substitutions = {
            "%%BZL_LOAD_PATH%%": public_load_path,
        },
    )

    stardoc(
        name = stardoc_name,
        func_template = _FUNC_TEMPLATE,
        header_template = header_name,
        rule_template = _RULE_TEMPLATE,
        provider_template = _PROVIDER_TEMPLATE,
        out = stardoc_out,
        **kwargs
    )

    if footer:
        native.genrule(
            name = name,
            srcs = [stardoc_out, footer],
            outs = [out],
            cmd = "cat $(SRCS) > $(OUTS)",
            message = "SphinxStardoc: Adding footer to {}".format(name),
            **copy_propagating_kwargs(kwargs)
        )

def _expand_stardoc_template_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".vm")
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = out,
        substitutions = ctx.attr.substitutions,
    )
    return [DefaultInfo(files = depset([out]))]

_expand_stardoc_template = rule(
    implementation = _expand_stardoc_template_impl,
    attrs = {
        "substitutions": attr.string_dict(),
        "template": attr.label(allow_single_file = True),
    },
)
