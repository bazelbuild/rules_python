# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Module extensions for use with bzlmod"

load("@rules_python//python:pip.bzl", "pip_parse")
load("@rules_python//python:repositories.bzl", "python_register_toolchains")
load("@rules_python//python/pip_install:pip_repository.bzl", "locked_requirements_label", "pip_repository_attrs", "use_isolated", "whl_library")
load("@rules_python//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("@rules_python//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("@rules_python//python/private:coverage_deps.bzl", "install_coverage_deps")

def _python_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.toolchain:
            python_register_toolchains(
                name = attr.name,
                python_version = attr.python_version,
                bzlmod = True,
                # Toolchain registration in bzlmod is done in MODULE file
                register_toolchains = False,
                register_coverage_tool = attr.configure_coverage_tool,
            )

python = module_extension(
    implementation = _python_impl,
    tag_classes = {
        "toolchain": tag_class(
            attrs = {
                "configure_coverage_tool": attr.bool(
                    mandatory = False,
                    doc = "Whether or not to configure the default coverage tool for the toolchains.",
                ),
                "name": attr.string(mandatory = True),
                "python_version": attr.string(mandatory = True),
            },
        ),
    },
)

# buildifier: disable=unused-variable
def _internal_deps_impl(module_ctx):
    pip_install_dependencies()
    install_coverage_deps()

internal_deps = module_extension(
    implementation = _internal_deps_impl,
    tag_classes = {
        "install": tag_class(attrs = dict()),
    },
)

def _pip_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.parse:
            requrements_lock = locked_requirements_label(module_ctx, attr)

            # Parse the requirements file directly in starlark to get the information
            # needed for the whl_libary declarations below. This is needed to contain
            # the pip_parse logic to a single module extension.
            requirements_lock_content = module_ctx.read(requrements_lock)
            parse_result = parse_requirements(requirements_lock_content)
            requirements = parse_result.requirements
            extra_pip_args = attr.extra_pip_args + parse_result.options

            # Create the repository where users load the `requirement` macro. Under bzlmod
            # this does not create the install_deps() macro.
            pip_parse(
                name = attr.name,
                requirements_lock = attr.requirements_lock,
                bzlmod = True,
                timeout = attr.timeout,
                python_interpreter = attr.python_interpreter,
                python_interpreter_target = attr.python_interpreter_target,
                quiet = attr.quiet,
            )

            for name, requirement_line in requirements:
                whl_library(
                    name = "%s_%s" % (attr.name, _sanitize_name(name)),
                    requirement = requirement_line,
                    repo = attr.name,
                    repo_prefix = attr.name + "_",
                    annotation = attr.annotations.get(name),
                    python_interpreter = attr.python_interpreter,
                    python_interpreter_target = attr.python_interpreter_target,
                    quiet = attr.quiet,
                    timeout = attr.timeout,
                    isolated = use_isolated(module_ctx, attr),
                    extra_pip_args = extra_pip_args,
                    download_only = attr.download_only,
                    pip_data_exclude = attr.pip_data_exclude,
                    enable_implicit_namespace_pkgs = attr.enable_implicit_namespace_pkgs,
                    environment = attr.environment,
                )

# Keep in sync with python/pip_install/tools/bazel.py
def _sanitize_name(name):
    return name.replace("-", "_").replace(".", "_").lower()

def _pip_parse_ext_attrs():
    attrs = dict({
        "name": attr.string(mandatory = True),
    }, **pip_repository_attrs)

    # Like the pip_parse macro, we end up setting this manually so
    # don't allow users to override it.
    attrs.pop("repo_prefix")

    return attrs

pip = module_extension(
    implementation = _pip_impl,
    tag_classes = {
        "parse": tag_class(attrs = _pip_parse_ext_attrs()),
    },
)
