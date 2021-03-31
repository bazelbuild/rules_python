# Copyright 2017 Google Inc. All rights reserved.
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
"""Import .whl files into Bazel."""

def _whl_impl(repository_ctx):
    """Core implementation of whl_library."""

    args = [
        repository_ctx.attr.python_interpreter,
        repository_ctx.path(repository_ctx.attr._script),
        "--whl",
        repository_ctx.path(repository_ctx.attr.whl),
        "--requirements",
        repository_ctx.attr.requirements,
    ]

    if repository_ctx.attr.extras:
        args += [
            "--extras=%s" % extra
            for extra in repository_ctx.attr.extras
        ]

    result = repository_ctx.execute(args)
    if result.return_code:
        fail("whl_library failed: %s (%s)" % (result.stdout, result.stderr))

whl_library = repository_rule(
    attrs = {
        "extras": attr.string_list(doc = """
A subset of the "extras" available from this <code>.whl</code> for which
<code>requirements</code> has the dependencies.
"""),
        "python_interpreter": attr.string(default = "python", doc = """
The command to run the Python interpreter used when unpacking the wheel.
"""),
        "requirements": attr.string(doc = """
The name of the <code>pip_import</code> repository rule from which to load this
<code>.whl</code>'s dependencies.
"""),
        "whl": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = """
The path to the <code>.whl</code> file. The name is expected to follow [this
convention](https://www.python.org/dev/peps/pep-0427/#file-name-convention)).
""",
        ),
        "_script": attr.label(
            executable = True,
            default = Label("//tools:whltool.par"),
            cfg = "host",
        ),
    },
    implementation = _whl_impl,
    doc = """A rule for importing `.whl` dependencies into Bazel.

<b>This rule is currently used to implement `pip_import`. It is not intended to
work standalone, and the interface may change.</b> See `pip_import` for proper
usage.

This rule imports a `.whl` file as a `py_library`:
```python
whl_library(
    name = "foo",
    whl = ":my-whl-file",
    requirements = "name of pip_import rule",
)
```

This rule defines `@foo//:pkg` as a `py_library` target.
""",
)
