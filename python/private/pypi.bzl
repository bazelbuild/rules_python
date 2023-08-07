def combine_intermediate_files(repository_ctx, installation_reports):
    combined = {}

    for intermediate_label, config_setting in installation_reports.items():
        intermediate = json.decode(repository_ctx.read(intermediate_label))
        for package in intermediate:
            config_settings = intermediate[package].keys()
            if len(config_settings) != 1:
                fail("Expected 1 config setting for package %s in %s, but got %d." \
                        % (package, intermediate_label, len(config_settings)))
            config_setting = config_settings[0]

            info = combined.setdefault(package, {})
            if config_setting in info:
                fail("Two intermediate files have the same config setting for package %s in %s." \
                        % (package, intermediate_label))
            info[config_setting] = intermediate[package][config_setting]

    return combined

def generate_pypi_package_load(repository_ctx):
    lines = [
        """load("@rules_python//python:pypi.bzl",""",
        """    _load_pypi_packages_internal="load_pypi_packages_internal",""",
        """    _generate_package_aliases="generate_package_aliases_internal",""",
        """)""",
        """load("@{}//:intermediate.bzl", "INTERMEDIATE")""".format(repository_ctx.name),
        """def load_pypi_packages(name, **kwargs):""",
        """    _load_pypi_packages_internal(INTERMEDIATE, alias_repo_name=name, **kwargs)""",
        """    _generate_package_aliases(name=name, intermediate="@{}//:intermediate.bzl", **kwargs)""".format(repository_ctx.name),
    ]
    repository_ctx.file("packages.bzl", "\n".join(lines), executable=False)
