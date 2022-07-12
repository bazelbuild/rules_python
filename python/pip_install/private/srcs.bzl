"""A generate file containing all source files used for `@rules_python//python/pip_install:pip_repository.bzl` rules

This file is auto-generated from the `@rules_python//python/pip_install/private:srcs_module.install` target. Please
`bazel run` this target to apply any updates. Note that doing so will discard any local modifications.
"""

# Each source file is tracked as a target so `pip_repository` rules will know to automatically rebuild if any of the
# sources changed.
PIP_INSTALL_PY_SRCS = [
    "@rules_python//python/pip_install/extract_wheels:__init__.py",
    "@rules_python//python/pip_install/extract_wheels:annotation.py",
    "@rules_python//python/pip_install/extract_wheels:arguments.py",
    "@rules_python//python/pip_install/extract_wheels:bazel.py",
    "@rules_python//python/pip_install/extract_wheels:extract_single_wheel.py",
    "@rules_python//python/pip_install/extract_wheels:extract_wheels.py",
    "@rules_python//python/pip_install/extract_wheels:namespace_pkgs.py",
    "@rules_python//python/pip_install/extract_wheels:parse_requirements_to_bzl.py",
    "@rules_python//python/pip_install/extract_wheels:requirements.py",
    "@rules_python//python/pip_install/extract_wheels:wheel.py",
]
