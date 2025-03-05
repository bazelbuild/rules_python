# Copyright 2025 The Bazel Authors. All rights reserved.
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

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "subjects", "truth")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python/private:attr_builders.bzl", "attrb")  # buildifier: disable=bzl-visibility

_tests = []

objs = {}

def _report_failures(name, env):
    failures = env.failures

    def _report_failures_impl(env, target):
        env._failures.extend(failures)

    analysis_test(
        name = name,
        target = "//python:none",
        impl = _report_failures_impl,
    )

def _loading_phase_expect(test_name):
    env = struct(
        ctx = struct(
            workspace_name = "bogus",
            label = Label(test_name),
            attr = struct(
                _impl_name = test_name,
            ),
        ),
        failures = [],
    )
    return env, truth.expect(env)

def _test_bool_defaults(name):
    env, expect = _loading_phase_expect(name)
    subject = attrb.Bool()
    expect.that_str(subject.doc.get()).equals("")
    expect.that_bool(subject.default.get()).equals(False)
    expect.that_bool(subject.mandatory.get()).equals(False)
    expect.that_dict(subject.extra_kwargs).contains_exactly({})

    expect.that_str(str(subject.build())).contains("attr.bool")
    _report_failures(name, env)

_tests.append(_test_bool_defaults)

def _test_bool_mutable(name):
    subject = attrb.Bool()
    subject.default.set(True)
    subject.mandatory.set(True)
    subject.doc.set("doc")
    subject.extra_kwargs["extra"] = "value"

    env, expect = _loading_phase_expect(name)
    expect.that_str(subject.doc.get()).equals("doc")
    expect.that_bool(subject.default.get()).equals(True)
    expect.that_bool(subject.mandatory.get()).equals(True)
    expect.that_dict(subject.extra_kwargs).contains_exactly({"extra": "value"})

    _report_failures(name, env)

_tests.append(_test_bool_mutable)

def attr_builders_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
