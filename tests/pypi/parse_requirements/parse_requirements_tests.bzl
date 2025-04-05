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
        "requirements_different_package_version": """\
foo==0.0.1+local \
    --hash=sha256:deadbeef
foo==0.0.1 \
    --hash=sha256:deadb00f
""",
        "requirements_direct": """\
foo[extra] @ https://some-url/package.whl
bar @ https://example.org/bar-1.0.whl --hash=sha256:deadbeef
baz @ https://test.com/baz-2.0.whl; python_version < "3.8" --hash=sha256:deadb00f
qux @ https://example.org/qux-1.0.tar.gz --hash=sha256:deadbe0f
""",
        "requirements_extra_args": """\
--index-url=example.org

foo[extra]==0.0.1 \
    --hash=sha256:deadbeef
""",
        "requirements_linux": """\
foo==0.0.3 --hash=sha256:deadbaaf
""",
        # download_only = True
        "requirements_linux_download_only": """\
--platform=manylinux_2_17_x86_64
--python-version=39
--implementation=cp
--abi=cp39

foo==0.0.1 --hash=sha256:deadbeef
bar==0.0.1 --hash=sha256:deadb00f
""",
        "requirements_lock": """\
foo[extra]==0.0.1 --hash=sha256:deadbeef
""",
        "requirements_lock_dupe": """\
foo[extra,extra_2]==0.0.1 --hash=sha256:deadbeef
foo==0.0.1 --hash=sha256:deadbeef
foo[extra]==0.0.1 --hash=sha256:deadbeef
""",
        "requirements_marker": """\
foo[extra]==0.0.1 ;marker --hash=sha256:deadbeef
bar==0.0.1 --hash=sha256:deadbeef
""",
        "requirements_optional_hash": """
foo==0.0.4 @ https://example.org/foo-0.0.4.whl
foo==0.0.5 @ https://example.org/foo-0.0.5.whl --hash=sha256:deadbeef
""",
        "requirements_osx": """\
foo==0.0.3 --hash=sha256:deadbaaf
""",
        "requirements_osx_download_only": """\
--platform=macosx_10_9_arm64
--python-version=39
--implementation=cp
--abi=cp39

foo==0.0.3 --hash=sha256:deadbaaf
""",
        "requirements_windows": """\
foo[extra]==0.0.2 --hash=sha256:deadbeef
bar==0.0.1 --hash=sha256:deadb00f
""",
        "requirements_sdist_different_hashes": """\
foo==0.0.1 --hash=sha256:deadbeef --hash=sha256:cafebabe
""",
        "requirements_sdist_different_hashes_linux": """\
foo==0.0.1 --hash=sha256:deadbaaf --hash=sha256:cafebabe
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
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "foo[extra]==0.0.1",
                    requirement_line = "foo[extra]==0.0.1 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = [
                    "linux_x86_64",
                    "windows_x86_64",
                ],
                whls = [],
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

def _test_direct_urls(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_direct": ["linux_x86_64"],
        },
    )
    env.expect.that_dict(got).contains_exactly({
        "bar": [
            struct(
                distribution = "bar",
                extra_pip_args = [],
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "bar @ https://example.org/bar-1.0.whl --hash=sha256:deadbeef",
                    requirement_line = "bar @ https://example.org/bar-1.0.whl --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "",
                    url = "https://example.org/bar-1.0.whl",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [struct(
                    url = "https://example.org/bar-1.0.whl",
                    filename = "bar-1.0.whl",
                    sha256 = "deadbeef",
                    yanked = False,
                )],
            ),
        ],
        "baz": [
            struct(
                distribution = "baz",
                extra_pip_args = [],
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "python_version < \"3.8\"",
                    requirement = "baz @ https://test.com/baz-2.0.whl --hash=sha256:deadb00f",
                    requirement_line = "baz @ https://test.com/baz-2.0.whl --hash=sha256:deadb00f",
                    shas = ["deadb00f"],
                    version = "",
                    url = "https://test.com/baz-2.0.whl",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [struct(
                    url = "https://test.com/baz-2.0.whl",
                    filename = "baz-2.0.whl",
                    sha256 = "deadb00f",
                    yanked = False,
                )],
            ),
        ],
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "foo[extra] @ https://some-url/package.whl",
                    requirement_line = "foo[extra] @ https://some-url/package.whl",
                    shas = [],
                    version = "",
                    url = "https://some-url/package.whl",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [struct(
                    url = "https://some-url/package.whl",
                    filename = "package.whl",
                    sha256 = "",
                    yanked = False,
                )],
            ),
        ],
        "qux": [
            struct(
                distribution = "qux",
                extra_pip_args = [],
                sdist = struct(
                    url = "https://example.org/qux-1.0.tar.gz",
                    filename = "qux-1.0.tar.gz",
                    sha256 = "deadbe0f",
                    yanked = False,
                ),
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "qux @ https://example.org/qux-1.0.tar.gz --hash=sha256:deadbe0f",
                    requirement_line = "qux @ https://example.org/qux-1.0.tar.gz --hash=sha256:deadbe0f",
                    shas = ["deadbe0f"],
                    version = "",
                    url = "https://example.org/qux-1.0.tar.gz",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
            ),
        ],
    })

_tests.append(_test_direct_urls)

def _test_extra_pip_args(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_extra_args": ["linux_x86_64"],
        },
        extra_pip_args = ["--trusted-host=example.org"],
    )
    env.expect.that_dict(got).contains_exactly({
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = ["--index-url=example.org", "--trusted-host=example.org"],
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "foo[extra]==0.0.1",
                    requirement_line = "foo[extra]==0.0.1 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = [
                    "linux_x86_64",
                ],
                whls = [],
            ),
        ],
    })
    env.expect.that_str(
        select_requirement(
            got["foo"],
            platform = "linux_x86_64",
        ).srcs.version,
    ).equals("0.0.1")

_tests.append(_test_extra_pip_args)

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
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "foo[extra,extra_2]==0.0.1",
                    requirement_line = "foo[extra,extra_2]==0.0.1 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
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
                srcs = struct(
                    marker = "",
                    requirement = "bar==0.0.1",
                    requirement_line = "bar==0.0.1 --hash=sha256:deadb00f",
                    shas = ["deadb00f"],
                    version = "0.0.1",
                    url = "",
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
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.3",
                    requirement_line = "foo==0.0.3 --hash=sha256:deadbaaf",
                    shas = ["deadbaaf"],
                    version = "0.0.3",
                    url = "",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
                sdist = None,
                is_exposed = True,
            ),
            struct(
                distribution = "foo",
                extra_pip_args = [],
                srcs = struct(
                    marker = "",
                    requirement = "foo[extra]==0.0.2",
                    requirement_line = "foo[extra]==0.0.2 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.2",
                    url = "",
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

def _test_multi_os_legacy(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_linux_download_only": ["cp39_linux_x86_64"],
            "requirements_osx_download_only": ["cp39_osx_aarch64"],
        },
    )

    env.expect.that_dict(got).contains_exactly({
        "bar": [
            struct(
                distribution = "bar",
                extra_pip_args = ["--platform=manylinux_2_17_x86_64", "--python-version=39", "--implementation=cp", "--abi=cp39"],
                is_exposed = False,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "bar==0.0.1",
                    requirement_line = "bar==0.0.1 --hash=sha256:deadb00f",
                    shas = ["deadb00f"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = ["cp39_linux_x86_64"],
                whls = [],
            ),
        ],
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = ["--platform=manylinux_2_17_x86_64", "--python-version=39", "--implementation=cp", "--abi=cp39"],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.1",
                    requirement_line = "foo==0.0.1 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = ["cp39_linux_x86_64"],
                whls = [],
            ),
            struct(
                distribution = "foo",
                extra_pip_args = ["--platform=macosx_10_9_arm64", "--python-version=39", "--implementation=cp", "--abi=cp39"],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement_line = "foo==0.0.3 --hash=sha256:deadbaaf",
                    requirement = "foo==0.0.3",
                    shas = ["deadbaaf"],
                    version = "0.0.3",
                    url = "",
                ),
                target_platforms = ["cp39_osx_aarch64"],
                whls = [],
            ),
        ],
    })

_tests.append(_test_multi_os_legacy)

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

def _test_env_marker_resolution(env):
    def _mock_eval_markers(input):
        ret = {
            "foo[extra]==0.0.1 ;marker --hash=sha256:deadbeef": ["cp311_windows_x86_64"],
        }

        env.expect.that_collection(input.keys()).contains_exactly(ret.keys())
        env.expect.that_collection(input.values()[0]).contains_exactly(["cp311_linux_super_exotic", "cp311_windows_x86_64"])
        return ret

    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_marker": ["cp311_linux_super_exotic", "cp311_windows_x86_64"],
        },
        evaluate_markers = _mock_eval_markers,
    )
    env.expect.that_dict(got).contains_exactly({
        "bar": [
            struct(
                distribution = "bar",
                extra_pip_args = [],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "bar==0.0.1",
                    requirement_line = "bar==0.0.1 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = ["cp311_linux_super_exotic", "cp311_windows_x86_64"],
                whls = [],
            ),
        ],
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                is_exposed = False,
                sdist = None,
                srcs = struct(
                    marker = "marker",
                    requirement = "foo[extra]==0.0.1",
                    requirement_line = "foo[extra]==0.0.1 --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = ["cp311_windows_x86_64"],
                whls = [],
            ),
        ],
    })
    env.expect.that_str(
        select_requirement(
            got["foo"],
            platform = "windows_x86_64",
        ).srcs.version,
    ).equals("0.0.1")

_tests.append(_test_env_marker_resolution)

def _test_different_package_version(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_different_package_version": ["linux_x86_64"],
        },
    )
    env.expect.that_dict(got).contains_exactly({
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.1",
                    requirement_line = "foo==0.0.1 --hash=sha256:deadb00f",
                    shas = ["deadb00f"],
                    version = "0.0.1",
                    url = "",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
            ),
            struct(
                distribution = "foo",
                extra_pip_args = [],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.1+local",
                    requirement_line = "foo==0.0.1+local --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.1+local",
                    url = "",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [],
            ),
        ],
    })

_tests.append(_test_different_package_version)

def _test_optional_hash(env):
    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_optional_hash": ["linux_x86_64"],
        },
    )
    env.expect.that_dict(got).contains_exactly({
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.4 @ https://example.org/foo-0.0.4.whl",
                    requirement_line = "foo==0.0.4 @ https://example.org/foo-0.0.4.whl",
                    shas = [],
                    version = "0.0.4",
                    url = "https://example.org/foo-0.0.4.whl",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [struct(
                    url = "https://example.org/foo-0.0.4.whl",
                    filename = "foo-0.0.4.whl",
                    sha256 = "",
                    yanked = False,
                )],
            ),
            struct(
                distribution = "foo",
                extra_pip_args = [],
                sdist = None,
                is_exposed = True,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.5 @ https://example.org/foo-0.0.5.whl --hash=sha256:deadbeef",
                    requirement_line = "foo==0.0.5 @ https://example.org/foo-0.0.5.whl --hash=sha256:deadbeef",
                    shas = ["deadbeef"],
                    version = "0.0.5",
                    url = "https://example.org/foo-0.0.5.whl",
                ),
                target_platforms = ["linux_x86_64"],
                whls = [struct(
                    url = "https://example.org/foo-0.0.5.whl",
                    filename = "foo-0.0.5.whl",
                    sha256 = "deadbeef",
                    yanked = False,
                )],
            ),
        ],
    })

_tests.append(_test_optional_hash)

def _test_sdist_different_hashes(env):
    """Test that sdists with same hash but wheels with different hashes across platforms are handled correctly."""

    def _mock_get_index_urls(_, distributions):
        return {
            "foo": struct(
                whls = {
                    "deadbeef": struct(
                        filename = "foo-0.0.1-py3-none-win_amd64.whl",
                        url = "https://pypi.org/foo-0.0.1-win.whl",
                        sha256 = "deadbeef",
                        yanked = False,
                    ),
                    "deadbaaf": struct(
                        filename = "foo-0.0.1-py3-none-manylinux_2_17_x86_64.whl",
                        url = "https://pypi.org/foo-0.0.1-linux.whl",
                        sha256 = "deadbaaf",
                        yanked = False,
                    ),
                },
                sdists = {
                    "cafebabe": struct(
                        filename = "foo-0.0.1.tar.gz",
                        url = "https://pypi.org/foo-0.0.1.tar.gz",
                        sha256 = "cafebabe",
                        yanked = False,
                    ),
                },
            ),
        }

    got = parse_requirements(
        ctx = _mock_ctx(),
        requirements_by_platform = {
            "requirements_sdist_different_hashes": ["cp315_windows_x86_64"],
            "requirements_sdist_different_hashes_linux": ["cp315_linux_x86_64"],
        },
        get_index_urls = _mock_get_index_urls,
    )
    env.expect.that_dict(got).contains_exactly({
        "foo": [
            struct(
                distribution = "foo",
                extra_pip_args = [],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.1",
                    requirement_line = "foo==0.0.1 --hash=sha256:deadbaaf --hash=sha256:cafebabe",
                    shas = ["cafebabe", "deadbaaf"],
                    url = "",
                    version = "0.0.1",
                ),
                target_platforms = ["cp315_linux_x86_64"],
                whls = [
                    struct(
                        filename = "foo-0.0.1-py3-none-manylinux_2_17_x86_64.whl",
                        url = "https://pypi.org/foo-0.0.1-linux.whl",
                        sha256 = "deadbaaf",
                        yanked = False,
                    ),
                ],
            ),
            struct(
                distribution = "foo",
                extra_pip_args = [],
                is_exposed = True,
                sdist = None,
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.1",
                    requirement_line = "foo==0.0.1 --hash=sha256:deadbeef --hash=sha256:cafebabe",
                    shas = ["cafebabe", "deadbeef"],
                    url = "",
                    version = "0.0.1",
                ),
                target_platforms = ["cp315_windows_x86_64"],
                whls = [
                    struct(
                        filename = "foo-0.0.1-py3-none-win_amd64.whl",
                        url = "https://pypi.org/foo-0.0.1-win.whl",
                        sha256 = "deadbeef",
                        yanked = False,
                    ),
                ],
            ),
            struct(
                distribution = "foo",
                extra_pip_args = [],
                is_exposed = True,
                sdist = struct(
                    filename = "foo-0.0.1.tar.gz",
                    url = "https://pypi.org/foo-0.0.1.tar.gz",
                    sha256 = "cafebabe",
                    yanked = False,
                ),
                srcs = struct(
                    marker = "",
                    requirement = "foo==0.0.1",
                    requirement_line = "foo==0.0.1 --hash=sha256:deadbaaf --hash=sha256:cafebabe",
                    shas = ["cafebabe", "deadbaaf"],
                    url = "",
                    version = "0.0.1",
                ),
                target_platforms = ["cp315_linux_x86_64", "cp315_windows_x86_64"],
                whls = [],
            ),
        ],
    })

_tests.append(_test_sdist_different_hashes)

def parse_requirements_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
