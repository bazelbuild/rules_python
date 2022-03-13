"""This module provides the gazelle_python_manifest macro that contains targets
for updating and testing the Gazelle manifest file.
"""

load("@io_bazel_rules_go//go:def.bzl", "go_binary")

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

    update_args = [
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
        embed = ["@rules_python//gazelle/manifest/generate:generate_lib"],
        data = [
            manifest,
            modules_mapping,
            requirements,
        ],
        args = update_args,
        visibility = ["//visibility:private"],
        tags = ["manual"],
    )

    test_binary = "_{}_test_bin".format(name)

    go_binary(
        name = test_binary,
        embed = ["@rules_python//gazelle/manifest/test:test_lib"],
        visibility = ["//visibility:private"],
    )

    native.sh_test(
        name = "{}.test".format(name),
        srcs = ["@rules_python//gazelle/manifest/test:run.sh"],
        data = [
            ":{}".format(test_binary),
            manifest,
            requirements,
        ],
        env = {
            "_TEST_BINARY": "$(rootpath :{})".format(test_binary),
            "_TEST_MANIFEST": "$(rootpath {})".format(manifest),
            "_TEST_REQUIREMENTS": "$(rootpath {})".format(requirements),
        },
        visibility = ["//visibility:private"],
    )
