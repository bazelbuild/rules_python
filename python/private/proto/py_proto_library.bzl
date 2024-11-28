# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""The implementation of the `py_proto_library` rule and its aspect."""

load("@rules_proto//proto:defs.bzl", "ProtoInfo", "proto_common")
load("//python:defs.bzl", "PyInfo")
load("//python/api:api.bzl", _py_common = "py_common")

PY_PROTO_TOOLCHAIN = "@rules_python//python/proto:toolchain_type"

_PyProtoInfo = provider(
    doc = "Encapsulates information needed by the Python proto rules.",
    fields = {
        "imports": """
            (depset[str]) The field forwarding PyInfo.imports coming from
            the proto language runtime dependency.""",
        "py_info": "PyInfo from proto runtime (or other deps) to propagate.",
        "runfiles_from_proto_deps": """
            (depset[File]) Files from the transitive closure implicit proto
            dependencies""",
        "transitive_sources": """(depset[File]) The Python sources.""",
    },
)

def _filter_provider(provider, *attrs):
    return [dep[provider] for attr in attrs for dep in attr if provider in dep]

def _incompatible_toolchains_enabled():
    return getattr(proto_common, "INCOMPATIBLE_ENABLE_PROTO_TOOLCHAIN_RESOLUTION", False)

def _py_proto_aspect_impl(target, ctx):
    """Generates and compiles Python code for a proto_library.

    The function runs protobuf compiler on the `proto_library` target generating
    a .py file for each .proto file.

    Args:
      target: (Target) A target providing `ProtoInfo`. Usually this means a
         `proto_library` target, but not always; you must expect to visit
         non-`proto_library` targets, too.
      ctx: (RuleContext) The rule context.

    Returns:
      ([_PyProtoInfo]) Providers collecting transitive information about
      generated files.
    """
    _proto_library = ctx.rule.attr

    # Check Proto file names
    for proto in target[ProtoInfo].direct_sources:
        if proto.is_source and "-" in proto.dirname:
            fail("Cannot generate Python code for a .proto whose path contains '-' ({}).".format(
                proto.path,
            ))

    if _incompatible_toolchains_enabled():
        toolchain = ctx.toolchains[PY_PROTO_TOOLCHAIN]
        if not toolchain:
            fail("No toolchains registered for '%s'." % PY_PROTO_TOOLCHAIN)
        proto_lang_toolchain_info = toolchain.proto
    else:
        proto_lang_toolchain_info = getattr(ctx.attr, "_aspect_proto_toolchain")[proto_common.ProtoLangToolchainInfo]

    py_common = _py_common.get(ctx)
    py_info = py_common.PyInfoBuilder().merge_target(
        proto_lang_toolchain_info.runtime,
    ).build()

    api_deps = [proto_lang_toolchain_info.runtime]

    generated_sources = []
    proto_info = target[ProtoInfo]
    proto_root = proto_info.proto_source_root
    if proto_info.direct_sources:
        # Generate py files
        generated_sources = proto_common.declare_generated_files(
            actions = ctx.actions,
            proto_info = proto_info,
            extension = "_pb2.py",
            name_mapper = lambda name: name.replace("-", "_").replace(".", "/"),
        )

        # Handles multiple repository and virtual import cases
        if proto_root.startswith(ctx.bin_dir.path):
            proto_root = proto_root[len(ctx.bin_dir.path) + 1:]

        plugin_output = ctx.bin_dir.path + "/" + proto_root
        proto_root = ctx.workspace_name + "/" + proto_root

        proto_common.compile(
            actions = ctx.actions,
            proto_info = proto_info,
            proto_lang_toolchain_info = proto_lang_toolchain_info,
            generated_files = generated_sources,
            plugin_output = plugin_output,
        )

    # Generated sources == Python sources
    python_sources = generated_sources

    deps = _filter_provider(_PyProtoInfo, getattr(_proto_library, "deps", []))
    runfiles_from_proto_deps = depset(
        transitive = [dep[DefaultInfo].default_runfiles.files for dep in api_deps] +
                     [dep.runfiles_from_proto_deps for dep in deps],
    )
    transitive_sources = depset(
        direct = python_sources,
        transitive = [dep.transitive_sources for dep in deps],
    )

    return [
        _PyProtoInfo(
            imports = depset(
                # Adding to PYTHONPATH so the generated modules can be
                # imported.  This is necessary when there is
                # strip_import_prefix, the Python modules are generated under
                # _virtual_imports. But it's undesirable otherwise, because it
                # will put the repo root at the top of the PYTHONPATH, ahead of
                # directories added through `imports` attributes.
                [proto_root] if "_virtual_imports" in proto_root else [],
                transitive = [dep[PyInfo].imports for dep in api_deps] + [dep.imports for dep in deps],
            ),
            runfiles_from_proto_deps = runfiles_from_proto_deps,
            transitive_sources = transitive_sources,
            py_info = py_info,
        ),
    ]

_py_proto_aspect = aspect(
    implementation = _py_proto_aspect_impl,
    attrs = _py_common.API_ATTRS | (
        {} if _incompatible_toolchains_enabled() else {
            "_aspect_proto_toolchain": attr.label(
                default = ":python_toolchain",
            ),
        }
    ),
    attr_aspects = ["deps"],
    required_providers = [ProtoInfo],
    provides = [_PyProtoInfo],
    toolchains = [PY_PROTO_TOOLCHAIN] if _incompatible_toolchains_enabled() else [],
)

def _py_proto_library_rule(ctx):
    """Merges results of `py_proto_aspect` in `deps`.

    Args:
      ctx: (RuleContext) The rule context.
    Returns:
      ([PyInfo, DefaultInfo, OutputGroupInfo])
    """
    if not ctx.attr.deps:
        fail("'deps' attribute mustn't be empty.")

    pyproto_infos = _filter_provider(_PyProtoInfo, ctx.attr.deps)
    default_outputs = depset(
        transitive = [info.transitive_sources for info in pyproto_infos],
    )

    py_common = _py_common.get(ctx)

    py_info = py_common.PyInfoBuilder()
    py_info.set_has_py2_only_sources(False)
    py_info.set_has_py3_only_sources(False)
    py_info.transitive_sources.add(default_outputs)
    py_info.imports.add([info.imports for info in pyproto_infos])
    py_info.merge_all([
        pyproto_info.py_info
        for pyproto_info in pyproto_infos
    ])
    return [
        DefaultInfo(
            files = default_outputs,
            default_runfiles = ctx.runfiles(transitive_files = depset(
                transitive =
                    [default_outputs] +
                    [info.runfiles_from_proto_deps for info in pyproto_infos],
            )),
        ),
        OutputGroupInfo(
            default = depset(),
        ),
        py_info.build(),
    ]

py_proto_library = rule(
    implementation = _py_proto_library_rule,
    doc = """
      Use `py_proto_library` to generate Python libraries from `.proto` files.

      The convention is to name the `py_proto_library` rule `foo_py_pb2`,
      when it is wrapping `proto_library` rule `foo_proto`.

      `deps` must point to a `proto_library` rule.

      Example:

```starlark
py_library(
    name = "lib",
    deps = [":foo_py_pb2"],
)

py_proto_library(
    name = "foo_py_pb2",
    deps = [":foo_proto"],
)

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)
```""",
    attrs = {
        "deps": attr.label_list(
            doc = """
              The list of `proto_library` rules to generate Python libraries for.

              Usually this is just the one target: the proto library of interest.
              It can be any target providing `ProtoInfo`.""",
            providers = [ProtoInfo],
            aspects = [_py_proto_aspect],
        ),
    } | _py_common.API_ATTRS,
    provides = [PyInfo],
)
