"""A generate file containing all source files used for `@rules_python//python/pip_install:pip_repository.bzl` rules

This file is auto-generated from the `@rules_python//python/pip_install/private:srcs_module.install` target. Please
`bazel run` this target to apply any updates. Note that doing so will discard any local modifications.
"""

# Each source file is tracked as a target so `pip_repository` rules will know to automatically rebuild if any of the
# sources changed.
PIP_INSTALL_PY_SRCS = [
    "@rules_python//python/pip_install/extract_wheels/lib:__init__.py",
    "@rules_python//python/pip_install/extract_wheels/lib:annotation.py",
    "@rules_python//python/pip_install/extract_wheels/lib:arguments.py",
    "@rules_python//python/pip_install/extract_wheels/lib:bazel.py",
    "@rules_python//python/pip_install/extract_wheels/lib:extract_single_wheel.py",
    "@rules_python//python/pip_install/extract_wheels/lib:extract_wheels.py",
    "@rules_python//python/pip_install/extract_wheels/lib:namespace_pkgs.py",
    "@rules_python//python/pip_install/extract_wheels/lib:parse_requirements_to_bzl.py",
    "@rules_python//python/pip_install/extract_wheels/lib:requirements.py",
    "@rules_python//python/pip_install/extract_wheels/lib:wheel.py",
]
