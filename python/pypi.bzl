load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:intermediate_pypi_install.bzl", "convert_installation_reports_to_intermediate")

def pypi_install(pip_installation_report = None, **kwargs):
    pip_installation_report_swapped = {}
    for config_setting, report in pip_installation_report.items():
        pip_installation_report_swapped[report] = config_setting
    _pypi_install(pip_installation_report = pip_installation_report_swapped, **kwargs)

def _pypi_install_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", """\
""", executable = False)
    if repository_ctx.attr.pip_installation_report:
        result = convert_installation_reports_to_intermediate(repository_ctx, repository_ctx.attr.pip_installation_report)
    else:
        result = {}
    repository_ctx.file("intermediate.json", json.encode_indent(result), executable=False)

_pypi_install = repository_rule(
    implementation = _pypi_install_impl,
    attrs = {
        "pip_installation_report": attr.label_keyed_string_dict(
            allow_files = True,
        ),
    },
)
