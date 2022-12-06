"""This module provides the gazelle_python_manifest macro that contains targets
for updating and testing the Gazelle manifest file.
"""

load("@io_bazel_rules_go//go:def.bzl", "GoSource", "go_binary")

def gazelle_python_manifest(
        name,
        requirements,
        modules_mapping,
        pip_repository_name = "",
        pip_repository_incremental = False,
        pip_deps_repository_name = "",
        manifest = ":gazelle_python.yaml"):
    """A macro for defining the updating and testing targets for the Gazelle manifest file.

    Args:
        name: the name used as a base for the targets.
        requirements: the target for the requirements.txt file.
        pip_repository_name: the name of the pip_install or pip_repository target.
        pip_repository_incremental: the incremental property of pip_repository.
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

    manifest_generator_hash = Label("//gazelle/manifest/generate:generate_lib_sources_hash")

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
    if pip_repository_incremental:
        update_args.append("--pip-repository-incremental")

    go_binary(
        name = update_target,
        embed = [Label("//gazelle/manifest/generate:generate_lib")],
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

    test_binary = "_{}_test_bin".format(name)

    go_binary(
        name = test_binary,
        embed = [Label("//gazelle/manifest/test:test_lib")],
        visibility = ["//visibility:private"],
    )

    native.sh_test(
        name = "{}.test".format(name),
        srcs = [Label("//gazelle/manifest/test:run.sh")],
        data = [
            ":{}".format(test_binary),
            manifest,
            requirements,
            manifest_generator_hash,
        ],
        env = {
            "_TEST_BINARY": "$(rootpath :{})".format(test_binary),
            "_TEST_MANIFEST": "$(rootpath {})".format(manifest),
            "_TEST_MANIFEST_GENERATOR_HASH": "$(rootpath {})".format(manifest_generator_hash),
            "_TEST_REQUIREMENTS": "$(rootpath {})".format(requirements),
        },
        visibility = ["//visibility:private"],
        timeout = "short",
    )

    native.filegroup(
        name = name,
        srcs = [manifest],
        tags = ["manual"],
        visibility = ["//visibility:public"],
    )

# buildifier: disable=provider-params
AllSourcesInfo = provider(fields = {"all_srcs": "All sources collected from the target and dependencies."})

_rules_python_workspace = Label("//:WORKSPACE")

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
            default = Label("//gazelle/manifest/hasher"),
            executable = True,
        ),
    },
)
