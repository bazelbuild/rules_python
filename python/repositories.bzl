# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""This file contains macros to be called during WORKSPACE evaluation.
"""

load(
    "//python/private:python_repositories.bzl",
    _STANDALONE_INTERPRETER_FILENAME = "STANDALONE_INTERPRETER_FILENAME",
    _is_standalone_interpreter = "is_standalone_interpreter",
    _py_repositories = "py_repositories",
    _python_register_multi_toolchains = "python_register_multi_toolchains",
    _python_register_toolchains = "python_register_toolchains",
    _python_repository = "python_repository",
)

py_repositories = _py_repositories
python_register_multi_toolchains = _python_register_multi_toolchains
python_register_toolchains = _python_register_toolchains

# Useful for documentation.
python_repository = _python_repository

# These symbols are of questionable public visibility. They were probably
# not intended to be actually public.
STANDALONE_INTERPRETER_FILENAME = _STANDALONE_INTERPRETER_FILENAME
is_standalone_interpreter = _is_standalone_interpreter
