"""A generate file containing all source files used for `@rules_python//python/pip_install:pip_repository.bzl` rules

This file is auto-generated from the `@rules_python//python/pip_install/private:srcs_module.install` target. Please
`bazel run` this target to apply any updates. Note that doing so will discard any local modifications.
"""

# Each source file is tracked as a target so `pip_repository` rules will know to automatically rebuild if any of the
# sources changed.
PIP_INSTALL_PY_SRCS = [
    "@rules_python//python/pip_install/extract_wheels:__init__.py",
    "@rules_python//python/pip_install/extract_wheels:__main__.py",
    "@rules_python//python/pip_install/extract_wheels/lib:__init__.py",
    "@rules_python//python/pip_install/extract_wheels/lib:annotation.py",
    "@rules_python//python/pip_install/extract_wheels/lib:arguments.py",
    "@rules_python//python/pip_install/extract_wheels/lib:bazel.py",
    "@rules_python//python/pip_install/extract_wheels/lib:namespace_pkgs.py",
    "@rules_python//python/pip_install/extract_wheels/lib:purelib.py",
    "@rules_python//python/pip_install/extract_wheels/lib:requirements.py",
    "@rules_python//python/pip_install/extract_wheels/lib:wheel.py",
    "@rules_python//python/pip_install/parse_requirements_to_bzl:__init__.py",
    "@rules_python//python/pip_install/parse_requirements_to_bzl:__main__.py",
    "@rules_python//python/pip_install/parse_requirements_to_bzl/extract_single_wheel:__init__.py",
    "@rules_python//python/pip_install/parse_requirements_to_bzl/extract_single_wheel:__main__.py",
]
