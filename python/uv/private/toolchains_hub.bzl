# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""A macro used from the uv_toolchain hub repo."""

load(":toolchain_types.bzl", "UV_TOOLCHAIN_TYPE")

def toolchains_hub(
        *,
        name = None,
        names,
        implementations,
        target_compatible_with,
        target_settings):
    # @unnamed-macro
    """Define the toolchains so that the lexicographical order registration is deterministic.

    Args:
        name: Unused.
        names: The names for toolchain targets.
        implementations: The name to label mapping.
        target_compatible_with: The name to target_compatible_with list mapping.
        target_settings: The name to target_settings list mapping.
    """
    if len(names) != len(implementations):
        fail("Each name must have an implementation")

    padding = len(str(len(names)))  # get the number of digits
    for i, name in sorted(enumerate(names), key = lambda x: -x[0]):
        # poor mans implementation leading 0
        number_prefix = ("0" * padding) + "{}".format(i)
        number_prefix = number_prefix[-padding:]

        native.toolchain(
            name = "{}_{}".format(number_prefix, name),
            target_compatible_with = target_compatible_with.get(name, []),
            target_settings = target_settings.get(name, []),
            toolchain = implementations[name],
            toolchain_type = UV_TOOLCHAIN_TYPE,
        )
