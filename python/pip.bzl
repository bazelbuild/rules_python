# Copyright 2017 The Bazel Authors. All rights reserved.
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
"""Import pip requirements into Bazel."""

import os

CACERT_PEM_DOWNLOAD_URL = "https://curl.haxx.se/ca/cacert.pem"

def _pip_import_impl(repository_ctx):
    """Core implementation of pip_import."""

    # Add an empty top-level BUILD file.
    # This is because Bazel requires BUILD files along all paths accessed
    # via //this/sort/of:path and we wouldn't be able to load our generated
    # requirements.bzl without it.
    repository_ctx.file("BUILD", "")
    
    # One of the things the original piptools.py script did was to extract 
    # cacerts.pem from pip._vendor.requests. This was already bad due to 
    # the access of a private package, but now it is actually broken with
    # later versions of pip. Instead, we'll obtain the cacert.pem file from
    # https://curl.haxx.se/ca/cacert.pem.  
    # (See https://curl.haxx.se/docs/caextract.html).
    cacert_pem_path = os.path.join(repository_ctx.path(""), "cacert.pem")
    repository_ctx.download(CACERT_PEM_DOWNLOAD_URL, cacert_pem_path)
    repository_ctx.report_progress("certificats downloaded to %s" % cacert_pem_path)
    
    # TODO: Get rid of the horrible Python3.5 hardcoding hack and use
    # .     something like py_runtime. This is needed at the present moment
    # .     to work around the hardcoding to Python2 in the original repo.
    
    # To see the output, pass: quiet=False
    
    python = repository_ctx.which("python3.5")
    script = repository_ctx.path(repository_ctx.attr._script)
    
    repository_ctx.report_progress(
        "About to execute %s %s..." % (python, script)
    )
    
    result = repository_ctx.execute([
        python,
        script,
        "--name",
        repository_ctx.attr.name,
        "--input",
        repository_ctx.path(repository_ctx.attr.requirements),
        "--output",
        repository_ctx.path("requirements.bzl"),
        "--certfile",
        cacert_pem_path,
        "--directory",
        repository_ctx.path(""),
    ], quiet=False)

    if result.return_code:
        fail("pip_import failed: %s (%s)" % (result.stdout, result.stderr))

pip_import = repository_rule(
    attrs = {
        "requirements": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_script": attr.label(
            executable = True,
            default = Label("//rules_python:piptool.py"),
            cfg = "host",
        ),
    },
    implementation = _pip_import_impl,
)

"""A rule for importing <code>requirements.txt</code> dependencies into Bazel.

This rule imports a <code>requirements.txt</code> file and generates a new
<code>requirements.bzl</code> file.  This is used via the <code>WORKSPACE</code>
pattern:
<pre><code>pip_import(
    name = "foo",
    requirements = ":requirements.txt",
)
load("@foo//:requirements.bzl", "pip_install")
pip_install()
</code></pre>

You can then reference imported dependencies from your <code>BUILD</code>
file with:
<pre><code>load("@foo//:requirements.bzl", "requirement")
py_library(
    name = "bar",
    ...
    deps = [
       "//my/other:dep",
       requirement("futures"),
       requirement("mock"),
    ],
)
</code></pre>

Or alternatively:
<pre><code>load("@foo//:requirements.bzl", "all_requirements")
py_binary(
    name = "baz",
    ...
    deps = [
       ":foo",
    ] + all_requirements,
)
</code></pre>

Args:
  requirements: The label of a requirements.txt file.
"""

def pip_repositories():
    """Pull in dependencies needed for pulling in pip dependencies.

    A placeholder method that will eventually pull in any dependencies
    needed to install pip dependencies.
    """
    pass
