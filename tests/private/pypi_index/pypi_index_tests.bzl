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
                " ".join(["{}=\"{}\"".format(key, value) for key, value in item.attrs.items()]),
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
                attrs = {
                    "data-requires-python": "&gt;=3.7",
                    "href": "https://example.org/full-url/foo-0.0.1.tar.gz#sha256=deadbeefasource",
                },
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
                attrs = {
                    "href": "https://example.org/full-url/foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl#sha256=deadbeef",
                    "data-requires-python": "&gt;=3.7",
                    "data-dist-info-metadata": "sha256=deadb00f",
                    "data-core-metadata": "sha256=deadb00f",
                },
                filename = "foo-0.0.2-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
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
    ]

    for (input, want) in tests:
        html = _generate_html(input)
        got = parse_simple_api_html(url = "ignored", content = html)
        env.expect.that_collection(got).has_size(1)
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

# <a href="https://example.org/full-url/foo-0.0.2-py3-none-any.whl#sha256=deadbeefawhl" data-requires-python="&gt;=3.7" data-tist-info-metadata="deadbeefametadata" data-core-metadata>cengal-3.2.5.tar.gz</a><br />
# <a href="https://files.pythonhosted.org/packages/b5/e7/6121e9cbc85af3028db8e24c2ab093998e40be93a9aff33b4a2ce474c3a0/cengal-3.2.5.tar.gz#sha256=47bd9f239cb3ad0fa80f9e722424b1780a220c2034a95ad05e76b96f8eb7b926" data-requires-python="&gt;=3.7" >cengal-3.2.5.tar.gz</a><br />
# <a href="https://files.pythonhosted.org/packages/f7/da/6a8858654fc80871e81fca22e503c7376b3e68a7681e0bd100c35daa1e69/cengal-3.2.6.tar.gz#sha256=19adb8b205484445cdeea0e10b7dbb89d867e8ab5902f678a023a5235fdc92e1" data-requires-python="&gt;=3.7" >cengal-3.2.6.tar.gz</a><br />
# <a href="https://files.pythonhosted.org/packages/f8/92/8d7a818c2840dda16bb810ec67832ef7f53939dd4b58066428133f225d4c/cengal-3.3.0.tar.gz#sha256=b25de1644ba7ce79d76f0c2a3dc04e84e9f68d6e027d4f0a67a271616932237c" data-requires-python="&gt;=3.7" >cengal-3.3.0.tar.gz</a><br />
# <a href="https://files.pythonhosted.org/packages/f1/95/f26c21fd7b1f1497cbf5c32e65a64b75ee3f27db8fa5745940a1edf41e62/cengal-3.4.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl#sha256=3ae64e4dd81d5f619c849d5423acd836b692d1aa153c6c7764c754dd9ef3bf08" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83" data-core-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83">cengal-3.4.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/00/57/2c9d903f24c8e6324b8aeb2a39f7278a5eee71054660a74d1dccc9c71b6b/cengal-3.4.0-cp310-cp310-musllinux_1_1_x86_64.whl#sha256=e520fa2f596df131143af88f5ffaea0e19dfe0424c79275642e933e9e1526c37" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83" data-core-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83">cengal-3.4.0-cp310-cp310-musllinux_1_1_x86_64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/71/5f/bc5234bd89dfd9392fe43e2b17b60e5c1bb08d677f0d6a3d9374bd858dc2/cengal-3.4.0-cp310-cp310-win_amd64.whl#sha256=8e5e49c54c31b9cf1df966e00789948ce4892fbcd3fc49c5b95a6bfb7bae8448" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=444e192258c0a0394c21067832f44f2d400bdc26bd0d2328948e277bbcade0b5" data-core-metadata="sha256=444e192258c0a0394c21067832f44f2d400bdc26bd0d2328948e277bbcade0b5">cengal-3.4.0-cp310-cp310-win_amd64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/f0/b5/5acb8e9ed17d232b0ddf53c0eac0af308d73f7bc5d9bf294c16558b4ab1e/cengal-3.4.0-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl#sha256=74508ed155ffea94f72ca01255efeed97881614de080426d67c9d376fd3ec358" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=d5f932ed8be9923eff07ea6129e8357ee2e8c4f3fa377c24e7296be10d7963f8" data-core-metadata="sha256=d5f932ed8be9923eff07ea6129e8357ee2e8c4f3fa377c24e7296be10d7963f8">cengal-3.4.0-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/fb/e6/0c26dd294cde3104ae26c26fb26e0c4458b24a99140cf8acb366dc005805/cengal-3.4.0-cp311-cp311-win_amd64.whl#sha256=a2b0c0802fda2896ed0ad3d54b3874e0d346a2b97660d48fc836be9090fe9d7f" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=327a2df927fcf6944de9e7b0c5ca9c1ecdd4b9cb58f5db9a8951446190fa10cc" data-core-metadata="sha256=327a2df927fcf6944de9e7b0c5ca9c1ecdd4b9cb58f5db9a8951446190fa10cc">cengal-3.4.0-cp311-cp311-win_amd64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/21/fa/6929e5dfa2f5d3ed3a7c3922b9445b112b68b2fec7a512c971f489dc6f93/cengal-3.4.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl#sha256=ebc5a0f1800c06ec6fafe4035d4313ccd3e798e68bc2531b04be350d3d85df31" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=d5f932ed8be9923eff07ea6129e8357ee2e8c4f3fa377c24e7296be10d7963f8" data-core-metadata="sha256=d5f932ed8be9923eff07ea6129e8357ee2e8c4f3fa377c24e7296be10d7963f8">cengal-3.4.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/cb/eb/644d13a694e36ea61265051d8c771760335fd289d01768d07ccceaf7cba1/cengal-3.4.0-cp312-cp312-win_amd64.whl#sha256=bf5b6b5492bc04363da1edb8bc1a0e272a49c4dc100cd6f90dfb26e04b567f3a" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=b5430f4b8a2d15a252449f1d25c4b3b2d49fa3b3a18174fd8371c7acdf71989e" data-core-metadata="sha256=b5430f4b8a2d15a252449f1d25c4b3b2d49fa3b3a18174fd8371c7acdf71989e">cengal-3.4.0-cp312-cp312-win_amd64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/4c/55/327755ee27ec4d988da25680c4ef0c663dcbcfc0b4fb52b7fd08e1d4fecd/cengal-3.4.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl#sha256=fdd256e323394f14d9d2caed1498494a654d0fdadc369cda84bae948cbe7d723" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83" data-core-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83">cengal-3.4.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl</a><br />
# <a href="https://files.pythonhosted.org/packages/bd/1c/9cb8da0bdcaff8157b0935885dbb2c377ad76dbab62e718696f4553b6dfb/cengal-3.4.0-cp38-cp38-musllinux_1_1_x86_64.whl#sha256=be5527986e585ec1fce0d77b3330f4e5d1678ee6f5e1452855a5edcd2b095033" data-requires-python="&gt;=3.7" data-dist-info-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83" data-core-metadata="sha256=e08cd424991fa8a5aa9034e2427792dfadb9f64c48ea06d6d5f98bb255d8cd83">cengal-3.4.0-cp38-cp38-musllinux_1_1_x86_64.whl</a><br />

def pypi_index_test_suite(name):
    """Create the test suite.

    Args:
        name: the name of the test suite
    """
    test_suite(name = name, basic_tests = _tests)
