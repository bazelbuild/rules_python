# Copyright 2022 The Bazel Authors. All rights reserved.
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
"""Rule implementation of py_binary for Bazel."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(":attributes.bzl", "AGNOSTIC_BINARY_ATTRS")
load(
    ":py_executable.bzl",
    "create_executable_rule",
    "py_executable_impl",
)

_PY_TEST_ATTRS = {
    # Magic attribute to help C++ coverage work. There's no
    # docs about this; see TestActionBuilder.java
    "_collect_cc_coverage": attr.label(
        default = "@bazel_tools//tools/test:collect_cc_coverage",
        executable = True,
        cfg = "exec",
    ),
    # Magic attribute to make coverage work. There's no
    # docs about this; see TestActionBuilder.java
    "_lcov_merger": attr.label(
        default = configuration_field(fragment = "coverage", name = "output_generator"),
        executable = True,
        cfg = "exec",
    ),
}

def _py_binary_impl(ctx):
    providers, binary_info, environment_info = py_executable_impl(
        ctx = ctx,
        is_test = False,
        inherited_environment = [],
    )
    providers.extend(
        [
            # We construct DefaultInfo and RunEnvironmentInfo here, as other py_binary-like
            # rules (py_test) need a different DefaultInfo and RunEnvironmentInfo.
            DefaultInfo(
                executable = binary_info.executable,
                files = binary_info.files,
                default_runfiles = binary_info.default_runfiles,
                data_runfiles = binary_info.data_runfiles,
            ),
            RunEnvironmentInfo(
                environment = environment_info.environment,
                inherited_environment = environment_info.inherited_environment,
            ),
        ],
    )
    return providers

py_binary = create_executable_rule(
    implementation = _py_binary_impl,
    attrs = dicts.add(AGNOSTIC_BINARY_ATTRS, _PY_TEST_ATTRS),
    executable = True,
)
