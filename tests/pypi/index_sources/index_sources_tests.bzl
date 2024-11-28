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
load("//python/private/pypi:index_sources.bzl", "index_sources")  # buildifier: disable=bzl-visibility

_tests = []

def _test_no_simple_api_sources(env):
    inputs = [
        "foo==0.0.1",
        "foo==0.0.1 @ https://someurl.org",
        "foo==0.0.1 @ https://someurl.org --hash=sha256:deadbeef",
        "foo==0.0.1 @ https://someurl.org; python_version < 2.7 --hash=sha256:deadbeef",
    ]
    for input in inputs:
        got = index_sources(input)
        env.expect.that_collection(got.shas).contains_exactly([])
        env.expect.that_str(got.version).equals("0.0.1")

_tests.append(_test_no_simple_api_sources)

def _test_simple_api_sources(env):
    tests = {
        "foo==0.0.2 --hash=sha256:deafbeef    --hash=sha256:deadbeef": [
            "deadbeef",
            "deafbeef",
        ],
        "foo[extra]==0.0.2; (python_version < 2.7 or something_else == \"@\") --hash=sha256:deafbeef    --hash=sha256:deadbeef": [
            "deadbeef",
            "deafbeef",
        ],
    }
    for input, want_shas in tests.items():
        got = index_sources(input)
        env.expect.that_collection(got.shas).contains_exactly(want_shas)
        env.expect.that_str(got.version).equals("0.0.2")

_tests.append(_test_simple_api_sources)

def index_sources_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
