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

"""This module provides the gazelle_python_manifest macro that contains targets
for updating and testing the Gazelle manifest file.
"""

load("@io_bazel_rules_go//go:def.bzl", "GoSource", "go_binary", "go_test")

def gazelle_python_manifest(
        name,
        requirements,
        modules_mapping,
        pip_repository_name = "",
        pip_deps_repository_name = "",
        manifest = ":gazelle_python.yaml",
        use_pip_repository_aliases = False):
    """A macro for defining the updating and testing targets for the Gazelle manifest file.

    Args:
        name: the name used as a base for the targets.
        requirements: the target for the requirements.txt file or a list of
            requirements files that will be concatenated before passing on to
            the manifest generator.
        pip_repository_name: the name of the pip_install or pip_repository target.
        use_pip_repository_aliases: boolean flag to enable using user-friendly
            python package aliases.
        pip_deps_repository_name: deprecated - the old pip_install target name.
        modules_mapping: the target for the generated modules_mapping.json file.
        manifest: the target for the Gazelle manifest file.
    """
    if pip_deps_repository_name != "":
        # buildifier: disable=print
        print("DEPRECATED pip_deps_repository_name in //{}:{}. Please use pip_repository_name instead.".format(
            native.package_name(),
            name,
        ))
        pip_repository_name = pip_deps_repository_name

    if pip_repository_name == "":
        # This is a temporary check while pip_deps_repository_name exists as deprecated.
        fail("pip_repository_name must be set in //{}:{}".format(native.package_name(), name))

    update_target = "{}.update".format(name)
    update_target_label = "//{}:{}".format(native.package_name(), update_target)

    manifest_generator_hash = Label("//manifest/generate:generate_lib_sources_hash")

    if type(requirements) == "list":
        native.genrule(
            name = name + "_requirements_gen",
            srcs = sorted(requirements),
            outs = [name + "_requirements.txt"],
            cmd_bash = "cat $(SRCS) > $@",
            cmd_bat = "type $(SRCS) > $@",
        )
        requirements = name + "_requirements_gen"

    update_args = [
        "--manifest-generator-hash",
        "$(rootpath {})".format(manifest_generator_hash),
        "--requirements",
        "$(rootpath {})".format(requirements),
        "--pip-repository-name",
        pip_repository_name,
        "--modules-mapping",
        "$(rootpath {})".format(modules_mapping),
        "--output",
        "$(rootpath {})".format(manifest),
        "--update-target",
        update_target_label,
    ]

    if use_pip_repository_aliases:
        update_args += [
            "--use-pip-repository-aliases",
            "true",
        ]

    go_binary(
        name = update_target,
        embed = [Label("//manifest/generate:generate_lib")],
        data = [
            manifest,
            modules_mapping,
            requirements,
            manifest_generator_hash,
        ],
        args = update_args,
        visibility = ["//visibility:private"],
        tags = ["manual"],
    )

    go_test(
        name = "{}.test".format(name),
        srcs = [Label("//manifest/test:test.go")],
        data = [
            manifest,
            requirements,
            manifest_generator_hash,
        ],
        env = {
            "_TEST_MANIFEST": "$(rootpath {})".format(manifest),
            "_TEST_MANIFEST_GENERATOR_HASH": "$(rootpath {})".format(manifest_generator_hash),
            "_TEST_REQUIREMENTS": "$(rootpath {})".format(requirements),
        },
        rundir = ".",
        deps = [Label("//manifest")],
        size = "small",
    )

    native.filegroup(
        name = name,
        srcs = [manifest],
        tags = ["manual"],
        visibility = ["//visibility:public"],
    )

# buildifier: disable=provider-params
AllSourcesInfo = provider(fields = {"all_srcs": "All sources collected from the target and dependencies."})

_rules_python_workspace = Label("@rules_python//:WORKSPACE")

def _get_all_sources_impl(target, ctx):
    is_rules_python = target.label.workspace_name == _rules_python_workspace.workspace_name
    if not is_rules_python:
        # Avoid adding third-party dependency files to the checksum of the srcs.
        return AllSourcesInfo(all_srcs = depset())
    srcs = depset(
        target[GoSource].orig_srcs,
        transitive = [dep[AllSourcesInfo].all_srcs for dep in ctx.rule.attr.deps],
    )
    return [AllSourcesInfo(all_srcs = srcs)]

_get_all_sources = aspect(
    implementation = _get_all_sources_impl,
    attr_aspects = ["deps"],
)

def _sources_hash_impl(ctx):
    all_srcs = ctx.attr.go_library[AllSourcesInfo].all_srcs
    hash_file = ctx.actions.declare_file(ctx.attr.name + ".hash")
    args = ctx.actions.args()
    args.add(hash_file)
    args.add_all(all_srcs)
    ctx.actions.run(
        outputs = [hash_file],
        inputs = all_srcs,
        arguments = [args],
        executable = ctx.executable._hasher,
    )
    return [DefaultInfo(
        files = depset([hash_file]),
        runfiles = ctx.runfiles([hash_file]),
    )]

sources_hash = rule(
    _sources_hash_impl,
    attrs = {
        "go_library": attr.label(
            aspects = [_get_all_sources],
            providers = [GoSource],
        ),
        "_hasher": attr.label(
            cfg = "exec",
            default = Label("//manifest/hasher"),
            executable = True,
        ),
    },
)
