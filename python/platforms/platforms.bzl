"""This module is used to construct the platforms in the BUILD file in this same package.
"""

# buildifier: disable=unnamed-macro
def construct_platforms(platforms, python_versions):
    """Constructs a set of constraints, platforms and configs for all platforms and Python versions.

    Args:
        platforms: The platforms rules_python support for the Python toolchains.
        python_versions: The Python versions supported by rules_python.
    """
    native.constraint_setting(
        name = "python_version",
        visibility = ["//visibility:private"],
    )

    for python_version in python_versions:
        python_version_constraint_value = "is_python_" + python_version
        native.constraint_value(
            name = python_version_constraint_value,
            constraint_setting = ":python_version",
            visibility = ["//visibility:public"],
        )

        for [platform_name, meta] in platforms:
            native.platform(
                name = "{platform_name}_{python_version}_platform".format(
                    platform_name = platform_name,
                    python_version = python_version,
                ),
                constraint_values = meta.compatible_with + [":" + python_version_constraint_value],
                visibility = ["//visibility:public"],
            )

            native.config_setting(
                name = "{platform_name}_{python_version}_config".format(
                    platform_name = platform_name,
                    python_version = python_version,
                ),
                constraint_values = meta.compatible_with + [":" + python_version_constraint_value],
                visibility = ["//visibility:public"],
            )
