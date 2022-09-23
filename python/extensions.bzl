"Module extensions for use with bzlmod"

load("@rules_python//python:pip.bzl", "pip_install")
load("@rules_python//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("@rules_python//python/pip_install:pip_repository.bzl", "pip_repository_attrs")

def _pip_install_internal_deps_impl(_):
    pip_install_dependencies()

pip_install_internal_deps = module_extension(
    implementation = _pip_install_internal_deps_impl,
)

def _pip_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.install:
            pip_install(
                name = attr.name,
                annotations = attr.annotations,
                incremental = attr.incremental,
                requirements = attr.requirements,
                requirements_darwin = attr.requirements_darwin,
                requirements_linux = attr.requirements_linux,
                requirements_lock = attr.requirements_lock,
                requirements_windows = attr.requirements_windows,
                download_only = attr.download_only,
                enable_implicit_namespace_pkgs = attr.enable_implicit_namespace_pkgs,
                environment = attr.environment,
                extra_pip_args = attr.extra_pip_args,
                isolated = attr.isolated,
                pip_data_exclude = attr.pip_data_exclude,
                python_interpreter = attr.python_interpreter,
                python_interpreter_target = attr.python_interpreter_target,
                quiet = attr.quiet,
                timeout = attr.timeout,
            )

pip = module_extension(
    implementation = _pip_impl,
    tag_classes = {
        "install": tag_class(attrs = dict({"name": attr.string()}, **pip_repository_attrs)),
        "parse": tag_class(attrs = dict()), # TODO
    },
)
