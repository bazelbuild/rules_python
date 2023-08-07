load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:pypi.bzl", "combine_intermediate_files", "generate_pypi_package_load")
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

def load_pypi_packages_internal(intermediate, alias_repo_name, **kwargs):
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

                # TODO(phil): Can we add target_compatible_with information
                # here?
                _generate_py_library(package, alias_repo_name, info)

def _generate_package_aliases_internal_impl(repository_ctx):
    bzl_intermediate = repository_ctx.read(repository_ctx.path(repository_ctx.attr.intermediate))
    if not bzl_intermediate.startswith("INTERMEDIATE = "):
        fail("Expected intermediate.bzl to start with 'INTERMEDIATE = '. Did the implementation get out of sync?")
    intermediate = json.decode(bzl_intermediate[len("INTERMEDIATE = "):])

    for package in intermediate:
        lines = [
            """load("{}", "INTERMEDIATE")""".format(repository_ctx.attr.intermediate),
            """load("@rules_python//python:pypi.bzl", _generate_package_alias="generate_package_alias")""",
            """_generate_package_alias(INTERMEDIATE)""",
        ]
        repository_ctx.file("{}/BUILD".format(package), "\n".join(lines), executable=False)

_generate_package_aliases_internal = repository_rule(
    implementation = _generate_package_aliases_internal_impl,
    attrs = {
        "intermediate": attr.label(
            allow_single_file = True,
        ),
    },
)

def generate_package_aliases_internal(**kwargs):
    _generate_package_aliases_internal(**kwargs)


def generate_package_alias(intermediate):
    package = native.package_name()
    if package not in intermediate:
        fail("Failed to find {} in the intermediate file. Something went wrong internally.")

    info_per_config = intermediate[package]
    actual_select = {}
    target_compatible_with_select = {
        "//conditions:default": ["@platforms//:incompatible"],
    }
    for config, info in info_per_config.items():
        repo_name = _generate_repo_name_for_extracted_wheel(package, info)
        actual_select[config] = "@{}//:library".format(repo_name)
        target_compatible_with_select[config] = []

    native.alias(
        name = package,
        actual = select(actual_select),
        # TODO(phil): Validate that this works in bazel 5. Do we care?
        target_compatible_with = select(target_compatible_with_select),
        visibility = ["//visibility:public"],
    )


def _generate_repo_name_for_download(package, info):
    # TODO(phil): Can we make it more human readable by avoiding the checksum?
    return "pypi_download_{}_{}".format(package, info["sha256"])

def _generate_repo_name_for_extracted_wheel(package, info):
    # TODO(phil): Can we make it more human readable by avoiding the checksum?
    return "pypi_extracted_wheel_{}_{}".format(package, info["sha256"])


def _generate_http_file(package, info):
    http_file(
        name = _generate_repo_name_for_download(package, info),
        urls = [
            info["url"],
        ],
        sha256 = info["sha256"],
        downloaded_file_path = paths.basename(info["url"]),
    )

def _generate_py_library(package, alias_repo_name, info):
    _wheel_library(
        name = _generate_repo_name_for_extracted_wheel(package, info),
        alias_repo_name = alias_repo_name,
        wheel_repo_name = _generate_repo_name_for_download(package, info),
        deps = info["deps"],
    )

def _wheel_library_impl(repository_ctx):
    deps = ['"@{}//{}"'.format(repository_ctx.attr.alias_repo_name, dep) for dep in repository_ctx.attr.deps]
    lines = [
        """load("@rules_python//python/private:wheel_library.bzl", "pycross_wheel_library")""",
        """pycross_wheel_library(""",
        """    name = "library",""",
        """    wheel = "@{}//file",""".format(repository_ctx.attr.wheel_repo_name),
        """    enable_implicit_namespace_pkgs = True,""",
        """    deps = [{}],""".format(",".join(deps)),
        """    visibility = ["//visibility:public"],""",
        # TODO(phil): Add deps here.
        """)""",
    ]
    repository_ctx.file("BUILD", "\n".join(lines), executable=False)

_wheel_library = repository_rule(
    implementation = _wheel_library_impl,
    attrs = {
        "alias_repo_name": attr.string(),
        "wheel_repo_name": attr.string(),
        "deps": attr.string_list(),
    },
)
