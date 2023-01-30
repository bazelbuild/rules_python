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
"""A generated file containing all source files used for `@rules_python//python/pip_install:pip_repository.bzl` rules

This file is auto-generated from the `@rules_python//python/pip_install/private:srcs_module.update` target. Please
`bazel run` this target to apply any updates. Note that doing so will discard any local modifications.
"""

# Each source file is tracked as a target so `pip_repository` rules will know to automatically rebuild if any of the
# sources changed.
PIP_INSTALL_PY_SRCS = [
    "@rules_python//python/pip_install/tools/dependency_resolver:__init__.py",
    "@rules_python//python/pip_install/tools/dependency_resolver:dependency_resolver.py",
    "@rules_python//python/pip_install/tools/lib:__init__.py",
    "@rules_python//python/pip_install/tools/lib:annotation.py",
    "@rules_python//python/pip_install/tools/lib:arguments.py",
    "@rules_python//python/pip_install/tools/lib:bazel.py",
    "@rules_python//python/pip_install/tools/lock_file_generator:__init__.py",
    "@rules_python//python/pip_install/tools/lock_file_generator:lock_file_generator.py",
    "@rules_python//python/pip_install/tools/wheel_installer:namespace_pkgs.py",
    "@rules_python//python/pip_install/tools/wheel_installer:wheel.py",
    "@rules_python//python/pip_install/tools/wheel_installer:wheel_installer.py",
]
