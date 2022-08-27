"Module extensions for use with bzlmod"

load("@rules_python//python/pip_install:repositories.bzl", "pip_install_dependencies")

def _pip_install_impl(_):
    pip_install_dependencies()

pip_install = module_extension(
    implementation = _pip_install_impl,
)
