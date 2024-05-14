# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""Code that support testing of rules_python code."""

# Explicit Label() calls are required so that it resolves in @rules_python
# context instead of e.g. the @rules_testing context.
MAC = Label("//tests/support:mac")
LINUX = Label("//tests/support:linux")
WINDOWS = Label("//tests/support:windows")

PLATFORM_TOOLCHAIN = Label("//tests/support:platform_toolchain")

# str() around Label() is necessary because rules_testing's config_settings
# doesn't accept yet Label objects.
PRECOMPILE = str(Label("//python/config_settings:precompile"))
PYC_COLLECTION = str(Label("//python/config_settings:pyc_collection"))
PRECOMPILE_SOURCE_RETENTION = str(Label("//python/config_settings:precompile_source_retention"))
PRECOMPILE_ADD_TO_RUNFILES = str(Label("//python/config_settings:precompile_add_to_runfiles"))
