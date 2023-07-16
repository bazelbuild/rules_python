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

""

load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//python/pip_install:entry_point.bzl", "entry_point")
load("//tests:test_env.bzl", "test_env")

def _label(label_str):
    # Bazel 5.4 is stringifying the labels differently.
    #
    # This function can be removed when the minimum supported version is 6+
    if test_env.is_bazel_6_or_higher():
        return label_str
    else:
        return label_str.lstrip("@")

_tests = []

def _test_unknown_entry_point_returns_none(env):
    actual = entry_point(
        pkg = "foo",
        packages = {},
        tmpl = "dummy",
        default_version = "dummy",
    )

    # None is returned if the package is not found, we will fail in the place
    # where this is called.
    want = None

    # FIXME @aignas 2023-07-11: currently the rules_testing does not accept a
    # None to the dict subject.
    env.expect.that_int(actual).equals(want)

_tests.append(_test_unknown_entry_point_returns_none)

def _test_constraint_values_are_set_correctly(env):
    actual = entry_point(
        pkg = "foo",
        packages = {"foo": ["1.2.0", "1.2.3", "1.2.5"]},
        tmpl = "dummy",
        default_version = "1.2.3",
    )

    # Python constraints are set correctly
    want = {
        # NOTE @aignas 2023-07-07: label will contain the rules_python
        # when the macro is used outside rules_python
        _label("@//python/config_settings:is_python_1.2.0"): "dummy",
        _label("@//python/config_settings:is_python_1.2.5"): "dummy",
        "//conditions:default": "dummy",
    }
    env.expect.that_dict(actual).contains_exactly(want)

_tests.append(_test_constraint_values_are_set_correctly)

def _test_template_is_interpolated_correctly(env):
    actual = entry_point(
        pkg = "foo",
        script = "bar",
        packages = {"foo": ["1.3.3", "1.2.5"]},
        tmpl = "pkg={pkg} script={script} version={version_label}",
        default_version = "1.2.5",
    )

    # Template is interpolated correctly
    want = {
        _label("@//python/config_settings:is_python_1.3.3"): "pkg=foo script=bar version=13",
        "//conditions:default": "pkg=foo script=bar version=12",
    }
    env.expect.that_dict(actual).contains_exactly(want)

_tests.append(_test_template_is_interpolated_correctly)

def entry_point_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
