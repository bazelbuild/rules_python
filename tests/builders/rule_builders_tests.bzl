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
load("@rules_testing//lib:truth.bzl", "subjects")
load("@rules_testing//lib:util.bzl", rt_util = "util")
load("//python/private:attr_builders.bzl", "attrb")  # buildifier: disable=bzl-visibility
load("//python/private:rule_builders.bzl", "ruleb")  # buildifier: disable=bzl-visibility

BananaInfo = provider()

def _banana_impl(ctx):
    return [BananaInfo(
        color = ctx.attr.color,
        flavors = ctx.attr.flavors,
        organic = ctx.attr.organic,
        size = ctx.attr.size,
        origin = ctx.attr.origin,
        fertilizers = ctx.attr.fertilizers,
        xx = mybool,
    )]

banana = ruleb.Rule(
    implementation = _banana_impl,
    attrs = {
        "color": attrb.String(default = "yellow"),
        "flavors": attrb.StringList(),
        "organic": lambda: attrb.Bool(),
        "size": lambda: attrb.Int(default = 10),
        "origin": lambda: attrb.Label(),
        "fertilizers": attrb.LabelList(
            allow_files = True,
        ),
    },
).build()

_tests = []

mybool = attrb.Bool()

def _test_basic_rule(name):
    banana(
        name = name + "_subject",
        flavors = ["spicy", "sweet"],
        organic = True,
        size = 5,
        origin = "//python:none",
        fertilizers = [
            "nitrogen.txt",
            "phosphorus.txt",
        ],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _test_basic_rule_impl,
    )

def _test_basic_rule_impl(env, target):
    info = target[BananaInfo]
    env.expect.that_str(info.color).equals("yellow")
    env.expect.that_collection(info.flavors).contains_exactly(["spicy", "sweet"])
    env.expect.that_bool(info.organic).equals(True)
    env.expect.that_int(info.size).equals(5)

    # //python:none is an alias to //python/private:sentinel; we see the
    # resolved value, not the intermediate alias
    env.expect.that_target(info.origin).label().equals(Label("//python/private:sentinel"))

    env.expect.that_collection(info.fertilizers).transform(
        desc = "target.label",
        map_each = lambda t: t.label,
    ).contains_exactly([
        Label(":nitrogen.txt"),
        Label(":phosphorus.txt"),
    ])

_tests.append(_test_basic_rule)

def rule_builders_test_suite(name):
    test_suite(
        name = name,
        tests = _tests,
    )
