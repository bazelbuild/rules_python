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

"""# Rules to generate Sphinx documentation.

The general usage of the Sphinx rules requires two pieces:

1. Using `sphinx_docs` to define the docs to build and options for building.
2. Defining a `sphinx-build` binary to run Sphinx with the necessary
   dependencies to be used by (1).

Defining your own `sphinx-build` binary is necessary because Sphinx uses
a plugin model to support extensibility.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//python:py_binary.bzl", "py_binary")
load("//python/private:util.bzl", "add_tag", "copy_propagating_kwargs")  # buildifier: disable=bzl-visibility

_SPHINX_BUILD_MAIN_SRC = Label("//sphinxdocs:sphinx_build.py")
_SPHINX_SERVE_MAIN_SRC = Label("//sphinxdocs:sphinx_server.py")

def sphinx_build_binary(name, py_binary_rule = py_binary, **kwargs):
    """Create an executable with the sphinx-build command line interface.

    The `deps` must contain the sphinx library and any other extensions Sphinx
    needs at runtime.

    Args:
        name: (str) name of the target. The name "sphinx-build" is the
            conventional name to match what Sphinx itself uses.
        py_binary_rule: (optional callable) A `py_binary` compatible callable
            for creating the target. If not set, the regular `py_binary`
            rule is used. This allows using the version-aware rules, or
            other alternative implementations.
        **kwargs: Additional kwargs to pass onto `py_binary`. The `srcs` and
            `main` attributes must not be specified.
    """
    add_tag(kwargs, "@rules_python//sphinxdocs:sphinx_build_binary")
    py_binary_rule(
        name = name,
        srcs = [_SPHINX_BUILD_MAIN_SRC],
        main = _SPHINX_BUILD_MAIN_SRC,
        **kwargs
    )

def sphinx_docs(name, *, srcs = [], sphinx, config, formats, strip_prefix = "", **kwargs):
    """Generate docs using Sphinx.

    This generates two public targets:
        * `<name>`: The output of this target is a directory for each
          format Sphinx creates. This target also has a separate output
          group for each format. e.g. `--output_group=html` will only build
          the "html" format files.
        * `<name>.serve`: A binary that locally serves the HTML output. This
          allows previewing docs during development.

    Args:
        name: (str) name of the docs rule.
        srcs: (label list) The source files for Sphinx to process.
        sphinx: (label) the Sphinx tool to use for building
            documentation. Because Sphinx supports various plugins, you must
            construct your own `py_binary` target with the dependencies
            Sphinx needs for your documentation.
        config: (label) the Sphinx config file (`conf.py`) to use.
        formats: (list of str) the formats (`-b` flag) to generate documentation
            in. Each format will become an output group.
        strip_prefix: (str) A prefix to remove from the file paths of the
            source files. e.g., given `//docs:foo.md`, stripping `docs/`
            makes Sphinx see `foo.md` in its generated source directory.
        extra_opts: (list[str]) Additional options to pass onto Sphinx building.
        **kwargs: (dict) Common attributes to pass onto rules.
    """
    add_tag(kwargs, "@rules_python//sphinxdocs:sphinx_build_binary")
    common_kwargs = copy_propagating_kwargs(kwargs)

    _sphinx_docs(
        name = name,
        srcs = srcs,
        sphinx = sphinx,
        config = config,
        formats = formats,
        strip_prefix = strip_prefix,
        **kwargs
    )

    html_name = "_{}_html".format(name)
    native.filegroup(
        name = html_name,
        srcs = [name],
        output_group = "html",
        **common_kwargs
    )
    py_binary(
        name = name + ".serve",
        srcs = [_SPHINX_SERVE_MAIN_SRC],
        main = _SPHINX_SERVE_MAIN_SRC,
        data = [html_name],
        args = [
            "$(execpath {})".format(html_name),
        ],
        **common_kwargs
    )

def _sphinx_docs_impl(ctx):
    source_dir_path, inputs = _create_sphinx_source_tree(ctx)
    inputs.append(ctx.file.config)

    outputs = {}
    for format in ctx.attr.formats:
        output_dir = _run_sphinx(
            ctx = ctx,
            format = format,
            source_path = source_dir_path,
            output_prefix = paths.join(ctx.label.name, "_build"),
            inputs = inputs,
        )
        outputs[format] = output_dir
    return [
        DefaultInfo(files = depset(outputs.values())),
        OutputGroupInfo(**{
            format: depset([output])
            for format, output in outputs.items()
        }),
    ]

_sphinx_docs = rule(
    implementation = _sphinx_docs_impl,
    attrs = {
        "config": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Config file for Sphinx",
        ),
        "formats": attr.string_list(doc = "Output formats for Sphinx to create."),
        "sphinx": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "Sphinx binary to generate documentation.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Doc source files for Sphinx.",
        ),
        "strip_prefix": attr.string(doc = "Prefix to remove from input file paths."),
        "extra_opts": attr.string_list(
            doc = "Additional options to pass onto Sphinx. These are added after " +
                  "other options, but before the source/output args.",
        ),
    },
)

def _create_sphinx_source_tree(ctx):
    # Sphinx only accepts a single directory to read its doc sources from.
    # Because plain files and generated files are in different directories,
    # we need to merge the two into a single directory.
    source_prefix = paths.join(ctx.label.name, "_sources")
    source_marker = ctx.actions.declare_file(paths.join(source_prefix, "__marker"))
    ctx.actions.write(source_marker, "")
    sphinx_source_dir_path = paths.dirname(source_marker.path)
    sphinx_source_files = []
    for orig in ctx.files.srcs:
        source_rel_path = orig.short_path
        if source_rel_path.startswith(ctx.attr.strip_prefix):
            source_rel_path = source_rel_path[len(ctx.attr.strip_prefix):]

        sphinx_source = ctx.actions.declare_file(paths.join(source_prefix, source_rel_path))
        ctx.actions.symlink(
            output = sphinx_source,
            target_file = orig,
            progress_message = "Symlinking Sphinx source %{input} to %{output}",
        )
        sphinx_source_files.append(sphinx_source)

    return sphinx_source_dir_path, sphinx_source_files

def _run_sphinx(ctx, format, source_path, inputs, output_prefix):
    output_dir = ctx.actions.declare_directory(paths.join(output_prefix, format))

    args = ctx.actions.args()
    args.add("-T")  # Full tracebacks on error
    args.add("-b", format)
    args.add("-c", paths.dirname(ctx.file.config.path))
    args.add("-q")  # Suppress stdout informational text
    args.add("-j", "auto")  # Build in parallel, if possible
    args.add("-E")  # Don't try to use cache files. Bazel can't make use of them.
    args.add("-a")  # Write all files; don't try to detect "changed" files
    args.add_all(ctx.attr.extra_opts)
    args.add(source_path)
    args.add(output_dir.path)

    ctx.actions.run(
        executable = ctx.executable.sphinx,
        arguments = [args],
        inputs = inputs,
        outputs = [output_dir],
        mnemonic = "SphinxBuildDocs",
        progress_message = "Sphinx building {} for %{{label}}".format(format),
    )
    return output_dir
