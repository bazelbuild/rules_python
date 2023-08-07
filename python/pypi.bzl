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

load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:pypi.bzl", "combine_intermediate_files", "generate_pypi_package_load")

def pypi_install(pip_installation_report = None, **kwargs):
    pip_install_dependencies()

    pip_installation_report_swapped = {}
    for config_setting, report in pip_installation_report.items():
        pip_installation_report_swapped[report] = config_setting
    _pypi_install(pip_installation_report = pip_installation_report_swapped, **kwargs)

def _pypi_install_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", "\n", executable = False)
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
        # TODO(phil): Add support for a single installation report.
        "pip_installation_report": attr.label_keyed_string_dict(
            allow_files = True,
        ),
    },
)
