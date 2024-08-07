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

def _sphinx_stardoc(*, name, out, public_load_path = None, **kwargs):
    stardoc_name = "_{}_stardoc".format(name.lstrip("_"))
    stardoc_pb = stardoc_name + ".binaryproto"

    if not public_load_path:
        public_load_path = str(kwargs["input"])

    stardoc(
        name = stardoc_name,
        out = stardoc_pb,
        format = "proto",
        **kwargs
    )

    _stardoc_proto_to_markdown(
        name = name,
        src = stardoc_pb,
        output = out,
        public_load_path = public_load_path,
    )

def _stardoc_proto_to_markdown_impl(ctx):
    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.set_param_file_format("multiline")

    inputs = [ctx.file.src]
    args.add("--proto", ctx.file.src)
    args.add("--output", ctx.outputs.output)

    if ctx.attr.public_load_path:
        args.add("--public-load-path={}".format(ctx.attr.public_load_path))

    ctx.actions.run(
        executable = ctx.executable._proto_to_markdown,
        arguments = [args],
        inputs = inputs,
        outputs = [ctx.outputs.output],
        mnemonic = "SphinxStardocProtoToMd",
        progress_message = "SphinxStardoc: converting proto to markdown: %{input} -> %{output}",
    )

_stardoc_proto_to_markdown = rule(
    implementation = _stardoc_proto_to_markdown_impl,
    attrs = {
        "output": attr.output(mandatory = True),
        "public_load_path": attr.string(),
        "src": attr.label(allow_single_file = True, mandatory = True),
        "_proto_to_markdown": attr.label(
            default = "//sphinxdocs/private:proto_to_markdown",
            executable = True,
            cfg = "exec",
        ),
    },
)
