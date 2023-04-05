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

load("@rules_python//python:repositories.bzl", "python_register_toolchains")
load("@rules_python//python/pip_install:pip_repository.bzl", "locked_requirements_label", "pip_repository_attrs", "pip_repository_bzlmod", "use_isolated", "whl_library")
load("@rules_python//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("@rules_python//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("@rules_python//python/private:coverage_deps.bzl", "install_coverage_deps")
load("@rules_python//python/private:toolchains_repo.bzl", "get_host_os_arch", "get_host_platform")

def _python_impl(module_ctx):
    for mod in module_ctx.modules:
        for toolchain_attr in mod.tags.toolchain:
            python_register_toolchains(
                name = toolchain_attr.name,
                python_version = toolchain_attr.python_version,
                bzlmod = True,
                # Toolchain registration in bzlmod is done in MODULE file
                register_toolchains = False,
                register_coverage_tool = toolchain_attr.configure_coverage_tool,
                ignore_root_user_error = toolchain_attr.ignore_root_user_error,
            )
            host_hub_name = toolchain_attr.name + "_host_interpreter"
            _host_hub(
                name = host_hub_name,
                user_repo_prefix = toolchain_attr.name,
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
                "ignore_root_user_error": attr.bool(
                    default = False,
                    doc = "Whether the check for root should be ignored or not. This causes cache misses with .pyc files.",
                    mandatory = False,
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
            # the pip_repository logic to a single module extension.
            requirements_lock_content = module_ctx.read(requrements_lock)
            parse_result = parse_requirements(requirements_lock_content)
            requirements = parse_result.requirements
            extra_pip_args = attr.extra_pip_args + parse_result.options

            # Create the repository where users load the `requirement` macro. Under bzlmod
            # this does not create the install_deps() macro.
            pip_repository_bzlmod(
                name = attr.name,
                requirements_lock = attr.requirements_lock,
                incompatible_generate_aliases = attr.incompatible_generate_aliases,
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

    # Like the pip_repository rule, we end up setting this manually so
    # don't allow users to override it.
    attrs.pop("repo_prefix")

    return attrs

pip = module_extension(
    implementation = _pip_impl,
    tag_classes = {
        "parse": tag_class(attrs = _pip_parse_ext_attrs()),
    },
)

# This function allows us to build the label name of a label
# that is not passed into the current context.
# The module_label is the key element that is passed in.
# This value provides the root location of the labels
# See https://bazel.build/external/extension#repository_names_and_visibility
def _repo_mapped_label(module_label, extension_name, apparent):
    """Construct a canonical repo label accounting for repo mapping.

    Args:
        module_label: Label object of the module hosting the extension; see
          "_module" implicit attribute.
        extension_name: str, name of the extension that created the repo in `apparent`.
        apparent: str, a repo-qualified target string, but without the "@". e.g.
          "python38_x86_linux//:python". The repo name should use the apparent
          name used by the extension named by `ext_name` (i.e. the value of the
          `name` arg the extension passes to repository rules)
    """
    return Label("@@{module}~{extension_name}~{apparent}".format(
        module = module_label.workspace_name,
        extension_name = extension_name,
        apparent = apparent,
    ))

# We are doing some bazel stuff here that could use an explanation.
# The basis of this function is that we need to create a symlink to
# the python binary that exists in a different repo that we know is
# setup by rules_python.
#
# We are building a Label like
# @@rules_python~override~python~python3_x86_64-unknown-linux-gnu//:python
# and then the function creates a symlink named python to that Label.
# The tricky part is the "~override~" part can't be known in advance
# and will change depending on how and what version of rules_python
# is used. To figure that part out, an implicit attribute is used to
# resolve the module's current name (see "_module" attribute)
#
# We are building the Label name dynamically, and can do this even
# though the Label is not passed into this function.  If we choose
# not do this a user would have to write another 16 lines
# of configuration code, but we are able to save them that work
# because we know how rules_python works internally.  We are using
# functions from private:toolchains_repo.bzl which is where the repo
# is being built. The repo name differs between host OS and platforms
# and the functions from toolchains_repo gives us this functions that
# information.
def _host_hub_impl(repo_ctx):
    # Intentionally empty; this is only intended to be used by repository
    # rules, which don't process build file contents.
    repo_ctx.file("BUILD.bazel", "")

    # The two get_ functions we use are also utilized when building
    # the repositories for the different interpreters.
    (os, arch) = get_host_os_arch(repo_ctx)
    host_platform = "{}_{}//:python".format(
        repo_ctx.attr.user_repo_prefix,
        get_host_platform(os, arch),
    )

    # the attribute is set to attr.label(default = "//:_"), which
    # provides us the resolved, canonical, prefix for the module's repos.
    # The extension_name "python" is determined by the
    # name bound to the module_extension() call.
    # We then have the OS and platform specific name of the python
    # interpreter.
    label = _repo_mapped_label(repo_ctx.attr._module, "python", host_platform)

    # create the symlink in order to set the interpreter for pip.
    repo_ctx.symlink(label, "python")

# We use this rule to set the pip interpreter target when using different operating
# systems with the same project
_host_hub = repository_rule(
    implementation = _host_hub_impl,
    local = True,
    attrs = {
        "user_repo_prefix": attr.string(
            mandatory = True,
            doc = """\
The prefix to create the repository name.  Usually the name you used when you created the 
Python toolchain.
""",
        ),
        "_module": attr.label(default = "//:_"),
    },
)
