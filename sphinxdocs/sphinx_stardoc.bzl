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

_FUNC_TEMPLATE = Label("//sphinxdocs:func_template.vm")
_HEADER_TEMPLATE = Label("//sphinxdocs:header_template.vm")
_RULE_TEMPLATE = Label("//sphinxdocs:rule_template.vm")
_PROVIDER_TEMPLATE = Label("//sphinxdocs:provider_template.vm")

def sphinx_stardocs(name, docs, **kwargs):
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
        **kwargs: Additional kwargs to pass onto each `sphinx_stardoc` target
    """
    add_tag(kwargs, "@rules_python//sphinxdocs:sphinx_stardocs")
    common_kwargs = copy_propagating_kwargs(kwargs)

    stardocs = []
    for out_name, entry in docs.items():
        if types.is_string(entry):
            label = Label(entry)
            input = entry.replace("_bzl", ".bzl")
        else:
            label = entry["dep"]
            input = entry["input"]

        doc_name = "_{}_{}".format(name, out_name.replace("/", "_"))
        _sphinx_stardoc(
            name = doc_name,
            input = input,
            deps = [label],
            out = out_name,
            **kwargs
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

def _sphinx_stardoc(**kwargs):
    stardoc(
        func_template = _FUNC_TEMPLATE,
        header_template = _HEADER_TEMPLATE,
        rule_template = _RULE_TEMPLATE,
        provider_template = _PROVIDER_TEMPLATE,
        **kwargs
    )
