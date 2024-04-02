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
load("@rules_testing//lib:truth.bzl", "subjects")
load("//python/private:pypi_index.bzl", "get_simpleapi_sources", "parse_simple_api_html")  # buildifier: disable=bzl-visibility

_tests = []

def _test_no_simple_api_sources(env):
    inputs = [
        "foo==0.0.1",
        "foo==0.0.1 @ https://someurl.org",
        "foo==0.0.1 @ https://someurl.org --hash=sha256:deadbeef",
        "foo==0.0.1 @ https://someurl.org; python_version < 2.7 --hash=sha256:deadbeef",
    ]
    for input in inputs:
        got = get_simpleapi_sources(input)
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
        got = get_simpleapi_sources(input)
        env.expect.that_collection(got.shas).contains_exactly(want_shas)
        env.expect.that_str(got.version).equals("0.0.2")

_tests.append(_test_simple_api_sources)

def _generate_html(*items):
    return """\
<html>
  <head>
    <meta name="pypi:repository-version" content="1.1">
    <title>Links for foo</title>
  </head>
  <body>
    <h1>Links for cengal</h1>
{}
</body>
</html>
""".format(
        "\n".join([
            "<a {}>{}</a><br />".format(
                " ".join(item.attrs),
                item.filename,
            )
            for item in items
        ]),
    )

def _test_parse_simple_api_html(env):
    # buildifier: disable=unsorted-dict-items
    tests = [
        (
            struct(
                attrs = [
                    'href="https://example.org/full-url/foo-0.0.1.tar.gz#sha256=deadbeefasource"',
                    'data-requires-python="&gt;=3.7"',
                ],
                filename = "foo-0.0.1.tar.gz",
            ),
            struct(
                filename = "foo-0.0.1.tar.gz",
                metadata_sha256 = "",
                metadata_url = "",
                sha256 = "deadbeefasource",
                url = "https://example.org/full-url/foo-0.0.1.tar.gz",
                yanked = False,
            ),
        ),
        (
            struct(
                attrs = [
                    'href="https://example.org/full-url/foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl#sha256=deadbeef"',
                    'data-requires-python="&gt;=3.7"',
                    'data-dist-info-metadata="sha256=deadb00f"',
                    'data-core-metadata="sha256=deadb00f"',
                ],
                filename = "foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
            ),
            struct(
                filename = "foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
                metadata_sha256 = "deadb00f",
                metadata_url = "https://example.org/full-url/foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl.metadata",
                sha256 = "deadbeef",
                url = "https://example.org/full-url/foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
                yanked = False,
            ),
        ),
    ]

    for (input, want) in tests:
        html = _generate_html(input)
        got = parse_simple_api_html(url = "ignored", content = html)
        env.expect.that_collection(got).has_size(1)
        if not got:
            fail("expected at least one element, but did not get anything from:\n{}".format(html))

        actual = env.expect.that_struct(
            got[0],
            attrs = dict(
                filename = subjects.str,
                metadata_sha256 = subjects.str,
                metadata_url = subjects.str,
                sha256 = subjects.str,
                url = subjects.str,
                yanked = subjects.bool,
            ),
        )
        actual.filename().equals(want.filename)
        actual.metadata_sha256().equals(want.metadata_sha256)
        actual.metadata_url().equals(want.metadata_url)
        actual.sha256().equals(want.sha256)
        actual.url().equals(want.url)
        actual.yanked().equals(want.yanked)

_tests.append(_test_parse_simple_api_html)

def pypi_index_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
