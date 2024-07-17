# Copyright 2024 The Bazel Authors. All rights reserved.
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
load("//python/private/pypi:parse_requirements.bzl", "parse_requirements", "select_requirement")  # buildifier: disable=bzl-visibility

def _mock_ctx():
    testdata = {
        "requirements_direct": """\
foo[extra] @ https://some-url
""",
        "requirements_linux": """\
foo==0.0.3 --hash=sha256:deadbaaf
""",
        "requirements_lock": """\
foo[extra]==0.0.1 --hash=sha256:deadbeef
""",
        "requirements_lock_dupe": """\
foo[extra,extra_2]==0.0.1 --hash=sha256:deadbeef
foo==0.0.1 --hash=sha256:deadbeef
foo[extra]==0.0.1 --hash=sha256:deadbeef
""",
        "requirements_osx": """\
foo==0.0.3 --hash=sha256:deadbaaf
""",
        "requirements_windows": """\
foo[extra]==0.0.2 --hash=sha256:deadbeef
bar==0.0.1 --hash=sha256:deadb00f
""",
    }

    return struct(
        os = struct(
            name = "linux",
            arch = "x86_64",
        ),
        read = lambda x: testdata[x],
    )

_tests = []

def _test_simple(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_lock": ["linux_x86_64", "windows_x86_64"],
        },
    )
    env.expect.that_dict(got).contains_exactly({
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                requirement_line = "foo[extra]==0.0.1 --hash=sha256:deadbeef",
                srcs = struct(
                    requirement = "foo[extra]==0.0.1",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                ),
                target_platforms = [
                    "linux_x86_64",
                    "windows_x86_64",
                ],
                whls = [],
                sdist = None,
                is_exposed = True,
            ),
        ],
    })
    env.expect.that_str(
        select_requirement(
            got["foo"],
            platform = "linux_x86_64",
        ).srcs.version,
    ).equals("0.0.1")

_tests.append(_test_simple)

def _test_dupe_requirements(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_lock_dupe": ["linux_x86_64"],
        },
    )
    env.expect.that_dict(got).contains_exactly({
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                requirement_line = "foo[extra,extra_2]==0.0.1 --hash=sha256:deadbeef",
                srcs = struct(
                    requirement = "foo[extra,extra_2]==0.0.1",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
                sdist = None,
                is_exposed = True,
            ),
        ],
    })

_tests.append(_test_dupe_requirements)

def _test_multi_os(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_linux": ["linux_x86_64"],
            "requirements_windows": ["windows_x86_64"],
        },
    )

    env.expect.that_dict(got).contains_exactly({
        "bar": [
            struct(
                distribution = "bar",
                extra_pip_args = [],
                requirement_line = "bar==0.0.1 --hash=sha256:deadb00f",
                srcs = struct(
                    requirement = "bar==0.0.1",
                    shas = ["deadb00f"],
                    version = "0.0.1",
                ),
                target_platforms = ["windows_x86_64"],
                whls = [],
                sdist = None,
                is_exposed = False,
            ),
        ],
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                requirement_line = "foo==0.0.3 --hash=sha256:deadbaaf",
                srcs = struct(
                    requirement = "foo==0.0.3",
                    shas = ["deadbaaf"],
                    version = "0.0.3",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
                sdist = None,
                is_exposed = True,
            ),
            struct(
                distribution = "foo",
                extra_pip_args = [],
                requirement_line = "foo[extra]==0.0.2 --hash=sha256:deadbeef",
                srcs = struct(
                    requirement = "foo[extra]==0.0.2",
                    shas = ["deadbeef"],
                    version = "0.0.2",
                ),
                target_platforms = ["windows_x86_64"],
                whls = [],
                sdist = None,
                is_exposed = True,
            ),
        ],
    })
    env.expect.that_str(
        select_requirement(
            got["foo"],
            platform = "windows_x86_64",
        ).srcs.version,
    ).equals("0.0.2")

_tests.append(_test_multi_os)

def _test_select_requirement_none_platform(env):
    got = select_requirement(
        [
            struct(
                some_attr = "foo",
                target_platforms = ["linux_x86_64"],
            ),
        ],
        platform = None,
    )
    env.expect.that_str(got.some_attr).equals("foo")

_tests.append(_test_select_requirement_none_platform)

def _test_fail_no_python_version(env):
    errors = []
    parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_lock": [""],
        },
        get_index_urls = lambda _, __: {},
        fail_fn = errors.append,
    )
    env.expect.that_str(errors[0]).equals("'python_version' must be provided")

_tests.append(_test_fail_no_python_version)

def parse_requirements_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
