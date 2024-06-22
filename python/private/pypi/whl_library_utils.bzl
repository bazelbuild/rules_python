"""A generated file containing all source files used for `@rules_python//python/private/pypi:whl_library.bzl` rules

This file is auto-generated from the `@rules_python//tests/pypi/whl_library_utils:srcs.update` target. Please
`bazel run` this target to apply any updates. Note that doing so will discard any local modifications.
"""

# Each source file is tracked as a target so `pip_repository` rules will know to automatically rebuild if any of the
# sources changed.
PY_SRCS = [
    "@rules_python//python/private/pypi:repack_whl.py",
    "@rules_python//python/pip_install/tools/dependency_resolver:__init__.py",
    "@rules_python//python/pip_install/tools/dependency_resolver:dependency_resolver.py",
    "@rules_python//python/pip_install/tools/wheel_installer:arguments.py",
    "@rules_python//python/pip_install/tools/wheel_installer:namespace_pkgs.py",
    "@rules_python//python/pip_install/tools/wheel_installer:wheel.py",
    "@rules_python//python/pip_install/tools/wheel_installer:wheel_installer.py",
    "@rules_python//tools:wheelmaker.py",
]
