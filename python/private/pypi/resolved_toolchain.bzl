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

"""This module implements an alias rule to the resolved toolchain.
"""

load("//python/private:toolchain_types.bzl", "UV_TOOLCHAIN_TYPE")

_DOC = """\
Exposes a concrete toolchain which is the result of Bazel resolving the
toolchain for the execution or target platform.
Workaround for https://github.com/bazelbuild/bazel/issues/14009
"""

# Forward all the providers
def _uv_resolved_toolchain_impl(ctx):
    toolchain_info = ctx.toolchains["//python:uv_toolchain_type"]
    return [
        toolchain_info,
        toolchain_info.defaultinfo,
        toolchain_info.templatevariableinfo,
        toolchain_info.uvtoolchaininfo,
    ]

# Copied from java_toolchain_alias
# https://cs.opensource.google/bazel/bazel/+/master:tools/jdk/java_toolchain_alias.bzl
uv_resolved_toolchain = rule(
    implementation = _uv_resolved_toolchain_impl,
    toolchains = [UV_TOOLCHAIN_TYPE],
    doc = _DOC,
)
