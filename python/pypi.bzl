load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:intermediate_pypi_install.bzl", "combine_intermediate_files", "generate_pypi_package_load")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_skylib//lib:paths.bzl", "paths")

def pypi_install(pip_installation_report = None, **kwargs):
    pip_install_dependencies()

    pip_installation_report_swapped = {}
    for config_setting, report in pip_installation_report.items():
        pip_installation_report_swapped[report] = config_setting
    _pypi_install(pip_installation_report = pip_installation_report_swapped, **kwargs)

def _pypi_install_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", """\
""", executable = False)
    if repository_ctx.attr.pip_installation_report:
        intermediate = combine_intermediate_files(
                repository_ctx,
                repository_ctx.attr.pip_installation_report)
    else:
        intermediate = {}

    repository_ctx.file(
            "intermediate.bzl",
            "INTERMEDIATE = {}\n".format(json.encode_indent(intermediate)),
            executable=False)

    generate_pypi_package_load(repository_ctx)

_pypi_install = repository_rule(
    implementation = _pypi_install_impl,
    attrs = {
        "pip_installation_report": attr.label_keyed_string_dict(
            allow_files = True,
        ),
    },
)

def load_pypi_packages_internal(intermediate, name, **kwargs):
    # Only download a wheel/tarball once. We do this by tracking which SHA sums
    # we've downloaded already.
    sha_indexed_infos = {}

    for package, configs in intermediate.items():
        for config, info in configs.items():
            if info["sha256"] not in sha_indexed_infos:
                _generate_http_file(package, info)
                # TODO(phil): What do we need to track here? Can we switch to a
                # set()?
                sha_indexed_infos[info["sha256"]] = True


def _generate_repo_name_for_download(package, info):
    # TODO(phil): Can we make it more human readable by avoiding the checksum?
    return "pypi_extracted_download_{}_{}".format(package, info["sha256"])


def _generate_http_file(package, info):
    http_file(
        name = _generate_repo_name_for_download(package, info),
        urls = [
            info["url"],
        ],
        sha256 = info["sha256"],
        downloaded_file_path = paths.basename(info["url"]),
    )
