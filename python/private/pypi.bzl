# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("//python/private:wheel_library.bzl", "pycross_wheel_library")

def combine_intermediate_files(repository_ctx, installation_reports):
    combined = {}

    # TODO(phil): Figure out how to deal with a single intermediate file. What
    # "config" setting should that have?
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
        """load("@rules_python//python/private:pypi.bzl",""",
        """    _load_pypi_packages="load_pypi_packages",""",
        """    _generate_package_aliases="generate_package_aliases",""",
        """)""",
        """load("@{}//:intermediate.bzl", "INTERMEDIATE")""".format(repository_ctx.name),
        """def load_pypi_packages(name, **kwargs):""",
        """    _load_pypi_packages(INTERMEDIATE, alias_repo_name=name, **kwargs)""",
        """    _generate_package_aliases(name=name, intermediate="@{}//:intermediate.bzl", **kwargs)""".format(repository_ctx.name),
    ]
    repository_ctx.file("packages.bzl", "\n".join(lines), executable=False)

def load_pypi_packages(intermediate, alias_repo_name, **kwargs):
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

def _generate_package_aliases_impl(repository_ctx):
    bzl_intermediate = repository_ctx.read(repository_ctx.path(repository_ctx.attr.intermediate))
    if not bzl_intermediate.startswith("INTERMEDIATE = "):
        fail("Expected intermediate.bzl to start with 'INTERMEDIATE = '. Did the implementation get out of sync?")
    intermediate = json.decode(bzl_intermediate[len("INTERMEDIATE = "):])

    for package in intermediate:
        lines = [
            """load("{}", "INTERMEDIATE")""".format(repository_ctx.attr.intermediate),
            """load("@rules_python//python/private:pypi.bzl", _generate_package_alias="generate_package_alias")""",
            """_generate_package_alias(INTERMEDIATE)""",
        ]
        repository_ctx.file("{}/BUILD".format(package), "\n".join(lines), executable=False)

_generate_package_aliases = repository_rule(
    implementation = _generate_package_aliases_impl,
    attrs = {
        "intermediate": attr.label(
            allow_single_file = True,
        ),
    },
)

def generate_package_aliases(**kwargs):
    _generate_package_aliases(**kwargs)


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
    deps = ["@{}//{}".format(repository_ctx.attr.alias_repo_name, dep) for dep in repository_ctx.attr.deps]
    lines = [
        """load("@rules_python//python/private:pypi.bzl", "wrapped_py_wheel_library")""",
        """wrapped_py_wheel_library(name="library", wheel_repo_name="{}", deps={})""".format(
            repository_ctx.attr.wheel_repo_name,
            json.encode(deps),
        ),
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

def wrapped_py_wheel_library(name, wheel_repo_name, deps):
    pycross_wheel_library(
        name = "library",
        wheel = "@{}//file".format(wheel_repo_name),
        enable_implicit_namespace_pkgs = True,
        deps = deps,
        visibility = ["//visibility:public"],
    )
