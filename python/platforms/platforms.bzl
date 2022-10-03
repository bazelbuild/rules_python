def construct(platforms, python_versions):
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
