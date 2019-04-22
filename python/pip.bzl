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

CACERT_PEM_DOWNLOAD_URL = "https://curl.haxx.se/ca/cacert.pem"


_PY_LIBRARY_DECLARATION = """
py_library(
    name = "{name}",
    srcs = glob(["{name}/**/*.py"]),
    data = glob(["{name}/**/*"], exclude=["{name}/**/*.py", "{name}/**/* *", "{name}/BUILD", "{name}/WORKSPACE"]),
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["./{name}"],
    deps = [{dependencies}],
)
"""

def _install_pkginfo(repository_ctx, certfile):
    pip = repository_ctx.which(repository_ctx.attr.pip)
    result = repository_ctx.execute([
        pip,
        "--disable-pip-version-check", 
        "--cert", certfile,
        "install",
        "-y",
        "pkginfo"
    ])

    if result.return_code != 0:
        fail("Failed to install pkginfo")

    return repository_ctx.which("pkginfo")


def _get_whl_dependencies(repository_ctx, whl_path):
    pkginfo = repository_ctx.which("pkginfo")

    cmd = [
        pkginfo,
        "--single",
        "-f", "requires_dist",
        whl_path
    ]

    result = repository_ctx.execute(cmd)

    if result.return_code != 0:
        fail("Failed to execute '%s'\nstderr: %s\nstdout: %s\n" % (" ".join(cmd), result.stderr, result.stdout))

    # Output from pkginfo command above will look like:
    # protobuf (>=3.5.0.post1),grpcio (>=1.19.0),aiohttp,foo (?),bar
    deps = [dep.split(" ")[0].strip() for dep in result.stdout.split(",")]

    return deps


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
    cacert_pem_path = "/".join([repository_ctx.path(""), "cacert.pem"])
    repository_ctx.download(CACERT_PEM_DOWNLOAD_URL, cacert_pem_path)
    repository_ctx.report_progress("certificates downloaded to %s" % cacert_pem_path)

    # To see the output, pass: quiet=False

    # Everything piptools.py originally did, we're going to do manually here.

    pip = repository_ctx.which(repository_ctx.attr.pip)
    python = repository_ctx.which(repository_ctx.attr.python)
    pkginfo = _install_pkginfo(repository_ctx, cacert_pem_path)
    unzip = repository_ctx.which(repository_ctx.attr.unzip)

    pip_cmd = [
        pip,
        "--disable-pip-version-check", 
        "--cert", certfile,
        "wheel",
        "-r", repository_ctx.path(repository_ctx.attr.requirements),
        "-w", repository_ctx.path("")
    ]

    result = repository_ctx.execute(pip_cmd)

    if result.return_code != 0:
        fail("failed to run '%s'\nstdout: %s\nstderr: %s\n" % (" ".join(pip_cmd), result.stdout, result.stderr))

    wheel_files = [p for p in repository_ctx.path("").readdir() if p.basename.endswith(".whl")]

    wheels = {}

    for whl_file in wheel_files:
        name_parts = whl_file.base_name.split("-")
        package_name = name_parts[0]
        package_version = name_parts[1]
        deps = _get_whl_dependencies(repository_ctx, whl_file)
        unzip_path = repository_ctx.path("").get_child(package_name)
        unzip_cmd = [
            unzip,
            "-d", unzip_path,
            whl_file
        ]

        library_declaration = _PY_LIBRARY_DECLARATION.format(name=package_name,
                                                             dependencies=",".join(deps))
        repository_ctx.file(unzip_path.get_child("BUILD"), library_declaration)


pip_import = repository_rule(
    attrs = {
        "requirements": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "pip": attr.string(default="pip3.5", doc="Which pip version to use. Defaults to pip3.5."),
        "python": attr.string(default="python3.5", doc="Which python version to use. Defaults to python3.5"),
        "unzip": attr.string(default="/usr/bin/unzip", doc="Which unzip tool to use. Defaults to /usr/bin/unzip."),
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
