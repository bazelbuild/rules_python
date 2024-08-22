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

"""Implementation of sphinx rules."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//python:py_binary.bzl", "py_binary")
load("//python/private:util.bzl", "add_tag", "copy_propagating_kwargs")  # buildifier: disable=bzl-visibility
load(":sphinx_docs_library_info.bzl", "SphinxDocsLibraryInfo")

_SPHINX_BUILD_MAIN_SRC = Label("//sphinxdocs/private:sphinx_build.py")
_SPHINX_SERVE_MAIN_SRC = Label("//sphinxdocs/private:sphinx_server.py")

_SphinxSourceTreeInfo = provider(
    doc = "Information about source tree for Sphinx to build.",
    fields = {
        "source_root": """
:type: str

Path of the root directory for the source files (which are in DefaultInfo.files)
""",
    },
)

def sphinx_build_binary(name, py_binary_rule = py_binary, **kwargs):
    """Create an executable with the sphinx-build command line interface.

    The `deps` must contain the sphinx library and any other extensions Sphinx
    needs at runtime.

    Args:
        name: {type}`str` name of the target. The name "sphinx-build" is the
            conventional name to match what Sphinx itself uses.
        py_binary_rule: {type}`callable` A `py_binary` compatible callable
            for creating the target. If not set, the regular `py_binary`
            rule is used. This allows using the version-aware rules, or
            other alternative implementations.
        **kwargs: {type}`dict` Additional kwargs to pass onto `py_binary`. The `srcs` and
            `main` attributes must not be specified.
    """
    add_tag(kwargs, "@rules_python//sphinxdocs:sphinx_build_binary")
    py_binary_rule(
        name = name,
        srcs = [_SPHINX_BUILD_MAIN_SRC],
        main = _SPHINX_BUILD_MAIN_SRC,
        **kwargs
    )

def sphinx_docs(
        name,
        *,
        srcs = [],
        deps = [],
        renamed_srcs = {},
        sphinx,
        config,
        formats,
        strip_prefix = "",
        extra_opts = [],
        tools = [],
        **kwargs):
    """Generate docs using Sphinx.

    This generates three public targets:
    * `<name>`: The output of this target is a directory for each
      format Sphinx creates. This target also has a separate output
      group for each format. e.g. `--output_group=html` will only build
      the "html" format files.
    * `<name>_define`: A multi-string flag to add additional `-D`
      arguments to the Sphinx invocation. This is useful for overriding
      the version information in the config file for builds.
    * `<name>.serve`: A binary that locally serves the HTML output. This
      allows previewing docs during development.

    Args:
        name: {type}`Name` name of the docs rule.
        srcs: {type}`list[label]` The source files for Sphinx to process.
        deps: {type}`list[label]` of {obj}`sphinx_docs_library` targets.
        renamed_srcs: {type}`dict[label, dict]` Doc source files for Sphinx that
            are renamed. This is typically used for files elsewhere, such as top
            level files in the repo.
        sphinx: {type}`label` the Sphinx tool to use for building
            documentation. Because Sphinx supports various plugins, you must
            construct your own binary with the necessary dependencies. The
            {obj}`sphinx_build_binary` rule can be used to define such a binary, but
            any executable supporting the `sphinx-build` command line interface
            can be used (typically some `py_binary` program).
        config: {type}`label` the Sphinx config file (`conf.py`) to use.
        formats: (list of str) the formats (`-b` flag) to generate documentation
            in. Each format will become an output group.
        strip_prefix: {type}`str` A prefix to remove from the file paths of the
            source files. e.g., given `//docs:foo.md`, stripping `docs/` makes
            Sphinx see `foo.md` in its generated source directory. If not
            specified, then {any}`native.package_name` is used.
        extra_opts: {type}`list[str]` Additional options to pass onto Sphinx building.
            On each provided option, a location expansion is performed.
            See {any}`ctx.expand_location`.
        tools: {type}`list[label]` Additional tools that are used by Sphinx and its plugins.
            This just makes the tools available during Sphinx execution. To locate
            them, use {obj}`extra_opts` and `$(location)`.
        **kwargs: {type}`dict` Common attributes to pass onto rules.
    """
    add_tag(kwargs, "@rules_python//sphinxdocs:sphinx_docs")
    common_kwargs = copy_propagating_kwargs(kwargs)

    _sphinx_source_tree(
        name = name + "/_sources",
        srcs = srcs,
        deps = deps,
        renamed_srcs = renamed_srcs,
        config = config,
        strip_prefix = strip_prefix,
        **common_kwargs
    )
    _sphinx_docs(
        name = name,
        sphinx = sphinx,
        formats = formats,
        source_tree = name + "/_sources",
        extra_opts = extra_opts,
        tools = tools,
        **kwargs
    )

    html_name = "_{}_html".format(name.lstrip("_"))
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

    build_test(
        name = name + "_build_test",
        targets = [name],
        **kwargs  # kwargs used to pick up target_compatible_with
    )

def _sphinx_docs_impl(ctx):
    source_dir_path = ctx.attr.source_tree[_SphinxSourceTreeInfo].source_root
    inputs = ctx.attr.source_tree[DefaultInfo].files

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
        "extra_opts": attr.string_list(
            doc = "Additional options to pass onto Sphinx. These are added after " +
                  "other options, but before the source/output args.",
        ),
        "formats": attr.string_list(doc = "Output formats for Sphinx to create."),
        "source_tree": attr.label(
            doc = "Directory of files for Sphinx to process.",
            providers = [_SphinxSourceTreeInfo],
        ),
        "sphinx": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "Sphinx binary to generate documentation.",
        ),
        "tools": attr.label_list(
            cfg = "exec",
            doc = "Additional tools that are used by Sphinx and its plugins.",
        ),
        "_extra_defines_flag": attr.label(default = "//sphinxdocs:extra_defines"),
        "_extra_env_flag": attr.label(default = "//sphinxdocs:extra_env"),
        "_quiet_flag": attr.label(default = "//sphinxdocs:quiet"),
    },
)

def _run_sphinx(ctx, format, source_path, inputs, output_prefix):
    output_dir = ctx.actions.declare_directory(paths.join(output_prefix, format))

    args = ctx.actions.args()
    args.add("-T")  # Full tracebacks on error
    args.add("-b", format)

    if ctx.attr._quiet_flag[BuildSettingInfo].value:
        args.add("-q")  # Suppress stdout informational text
    args.add("-j", "auto")  # Build in parallel, if possible
    args.add("-E")  # Don't try to use cache files. Bazel can't make use of them.
    args.add("-a")  # Write all files; don't try to detect "changed" files
    for opt in ctx.attr.extra_opts:
        args.add(ctx.expand_location(opt))
    args.add_all(ctx.attr._extra_defines_flag[_FlagInfo].value, before_each = "-D")
    args.add(source_path)
    args.add(output_dir.path)

    env = dict([
        v.split("=", 1)
        for v in ctx.attr._extra_env_flag[_FlagInfo].value
    ])

    tools = []
    for tool in ctx.attr.tools:
        tools.append(tool[DefaultInfo].files_to_run)

    ctx.actions.run(
        executable = ctx.executable.sphinx,
        arguments = [args],
        inputs = inputs,
        outputs = [output_dir],
        tools = tools,
        mnemonic = "SphinxBuildDocs",
        progress_message = "Sphinx building {} for %{{label}}".format(format),
        env = env,
    )
    return output_dir

def _sphinx_source_tree_impl(ctx):
    # Sphinx only accepts a single directory to read its doc sources from.
    # Because plain files and generated files are in different directories,
    # we need to merge the two into a single directory.
    source_prefix = ctx.label.name
    sphinx_source_files = []

    # Materialize a file under the `_sources` dir
    def _relocate(source_file, dest_path = None):
        if not dest_path:
            dest_path = source_file.short_path.removeprefix(ctx.attr.strip_prefix)
        dest_file = ctx.actions.declare_file(paths.join(source_prefix, dest_path))
        ctx.actions.symlink(
            output = dest_file,
            target_file = source_file,
            progress_message = "Symlinking Sphinx source %{input} to %{output}",
        )
        sphinx_source_files.append(dest_file)
        return dest_file

    # Though Sphinx has a -c flag, we move the config file into the sources
    # directory to make the config more intuitive because some configuration
    # options are relative to the config location, not the sources directory.
    source_conf_file = _relocate(ctx.file.config)
    sphinx_source_dir_path = paths.dirname(source_conf_file.path)

    for src in ctx.attr.srcs:
        if SphinxDocsLibraryInfo in src:
            fail((
                "In attribute srcs: target {src} is misplaced here: " +
                "sphinx_docs_library targets belong in the deps attribute."
            ).format(src = src))

    for orig_file in ctx.files.srcs:
        _relocate(orig_file)

    for src_target, dest in ctx.attr.renamed_srcs.items():
        src_files = src_target.files.to_list()
        if len(src_files) != 1:
            fail("A single file must be specified to be renamed. Target {} " +
                 "generate {} files: {}".format(
                     src_target,
                     len(src_files),
                     src_files,
                 ))
        _relocate(src_files[0], dest)

    for t in ctx.attr.deps:
        info = t[SphinxDocsLibraryInfo]
        for entry in info.transitive.to_list():
            for original in entry.files:
                new_path = entry.prefix + original.short_path.removeprefix(entry.strip_prefix)
                _relocate(original, new_path)

    return [
        DefaultInfo(
            files = depset(sphinx_source_files),
        ),
        _SphinxSourceTreeInfo(
            source_root = sphinx_source_dir_path,
        ),
    ]

_sphinx_source_tree = rule(
    implementation = _sphinx_source_tree_impl,
    attrs = {
        "config": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Config file for Sphinx",
        ),
        "deps": attr.label_list(
            providers = [SphinxDocsLibraryInfo],
        ),
        "renamed_srcs": attr.label_keyed_string_dict(
            allow_files = True,
            doc = "Doc source files for Sphinx that are renamed. This is " +
                  "typically used for files elsewhere, such as top level " +
                  "files in the repo.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Doc source files for Sphinx.",
        ),
        "strip_prefix": attr.string(doc = "Prefix to remove from input file paths."),
    },
)
_FlagInfo = provider(
    doc = "Provider for a flag value",
    fields = ["value"],
)

def _repeated_string_list_flag_impl(ctx):
    return _FlagInfo(value = ctx.build_setting_value)

repeated_string_list_flag = rule(
    implementation = _repeated_string_list_flag_impl,
    build_setting = config.string_list(flag = True, repeatable = True),
)

def sphinx_inventory(*, name, src, **kwargs):
    """Creates a compressed inventory file from an uncompressed on.

    The Sphinx inventory format isn't formally documented, but is understood
    to be:

    ```
    # Sphinx inventory version 2
    # Project: <project name>
    # Version: <version string>
    # The remainder of this file is compressed using zlib
    name domain:role 1 relative-url display name
    ```

    Where:
      * `<project name>` is a string. e.g. `Rules Python`
      * `<version string>` is a string e.g. `1.5.3`

    And there are one or more `name domain:role ...` lines
      * `name`: the name of the symbol. It can contain special characters,
        but not spaces.
      * `domain:role`: The `domain` is usually a language, e.g. `py` or `bzl`.
        The `role` is usually the type of object, e.g. `class` or `func`. There
        is no canonical meaning to the values, they are usually domain-specific.
      * `1` is a number. It affects search priority.
      * `relative-url` is a URL path relative to the base url in the
        confg.py intersphinx config.
      * `display name` is a string. It can contain spaces, or simply be
        the value `-` to indicate it is the same as `name`

    :::{seealso}
    {bzl:obj}`//sphinxdocs/inventories` for inventories of Bazel objects.
    :::

    Args:
        name: {type}`Name` name of the target.
        src: {type}`label` Uncompressed inventory text file.
        **kwargs: {type}`dict` additional kwargs of common attributes.
    """
    _sphinx_inventory(name = name, src = src, **kwargs)

def _sphinx_inventory_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".inv")
    args = ctx.actions.args()
    args.add(ctx.file.src)
    args.add(output)
    ctx.actions.run(
        executable = ctx.executable._builder,
        arguments = [args],
        inputs = depset([ctx.file.src]),
        outputs = [output],
    )
    return [DefaultInfo(files = depset([output]))]

_sphinx_inventory = rule(
    implementation = _sphinx_inventory_impl,
    attrs = {
        "src": attr.label(allow_single_file = True),
        "_builder": attr.label(
            default = "//sphinxdocs/private:inventory_builder",
            executable = True,
            cfg = "exec",
        ),
    },
)
