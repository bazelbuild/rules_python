"""This module provides the gazelle_python_manifest macro that contains targets
for updating and testing the Gazelle manifest file.
"""

load("@io_bazel_rules_go//go:def.bzl", "go_binary")

def gazelle_python_manifest(
        name,
        requirements,
        pip_deps_repository_name,
        modules_mapping,
        manifest = ":gazelle_python.yaml"):
    """A macro for defining the updating and testing targets for the Gazelle manifest file.

    Args:
        name: the name used as a base for the targets.
        requirements: the target for the requirements.txt file.
        pip_deps_repository_name: the name of the pip_install repository target.
        modules_mapping: the target for the generated modules_mapping.json file.
        manifest: the target for the Gazelle manifest file.
    """
    update_target = "{}.update".format(name)
    update_target_label = "//{}:{}".format(native.package_name(), update_target)

    go_binary(
        name = update_target,
        embed = ["@rules_python//gazelle/manifest/generate:generate_lib"],
        data = [
            manifest,
            modules_mapping,
            requirements,
        ],
        args = [
            "--requirements",
            "$(rootpath {})".format(requirements),
            "--pip-deps-repository-name",
            pip_deps_repository_name,
            "--modules-mapping",
            "$(rootpath {})".format(modules_mapping),
            "--output",
            "$(rootpath {})".format(manifest),
            "--update-target",
            update_target_label,
        ],
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
