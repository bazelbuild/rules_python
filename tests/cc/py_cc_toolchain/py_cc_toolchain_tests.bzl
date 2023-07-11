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

"""Tests for py_cc_toolchain."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("//tests:cc_info_subject.bzl", "cc_info_subject")
load("//tests:default_info_subject.bzl", "default_info_subject")
load("//tests:py_cc_toolchain_info_subject.bzl", "PyCcToolchainInfoSubject")

_tests = []

def _py_cc_toolchain_test(name):
    analysis_test(
        name = name,
        impl = _py_cc_toolchain_test_impl,
        target = "//tests/cc:fake_py_cc_toolchain_impl",
        attrs = {
            "header": attr.label(
                default = "//tests/cc:fake_header.h",
                allow_single_file = True,
            ),
        },
    )

def _py_cc_toolchain_test_impl(env, target):
    env.expect.that_target(target).has_provider(platform_common.ToolchainInfo)

    toolchain = PyCcToolchainInfoSubject.new(
        target[platform_common.ToolchainInfo].py_cc_toolchain,
        meta = env.expect.meta.derive(expr = "py_cc_toolchain_info"),
    )
    toolchain.python_version().equals("3.999")

    headers_providers = toolchain.headers().providers_map()
    headers_providers.keys().contains_exactly(["CcInfo", "DefaultInfo"])

    cc_info = headers_providers.get("CcInfo", factory = cc_info_subject)

    compilation_context = cc_info.compilation_context()
    compilation_context.direct_headers().contains_exactly([
        env.ctx.file.header,
    ])
    compilation_context.direct_public_headers().contains_exactly([
        env.ctx.file.header,
    ])

    # NOTE: The include dir gets added twice, once for the source path,
    # and once for the config-specific path, but we don't care about that.
    compilation_context.system_includes().contains_at_least_predicates([
        matching.str_matches("*/fake_include"),
    ])

    # TODO: Once subjects.default_info is available, do
    # default_info = headers_providers.get("DefaultInfo", factory=subjects.default_info)
    # https://github.com/bazelbuild/rules_python/issues/1297
    default_info = default_info_subject(
        headers_providers.get("DefaultInfo", factory = lambda v, meta: v),
        meta = env.expect.meta.derive(expr = "default_info"),
    )
    default_info.runfiles().contains_predicate(
        matching.str_matches("*/cc/data.txt"),
    )

_tests.append(_py_cc_toolchain_test)

def py_cc_toolchain_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
