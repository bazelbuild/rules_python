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
    srcs = [
        {srcs}
    ],
    data = [
        {data}
    ],
    # This makes this directory a top-level in the python import
    # search path for anything that depends on this.
    imports = ["."],
    deps = [
        {dependencies}
    ],
    visibility = ["//visibility:public"],
)

"""

_BUILD = """
load("@io_bazel_rules_python//python:python.bzl", "py_library")

{library_declarations}
"""

_REQUIREMENTS_BZL = """

def pip_install():
    # Does nothing
    pass

_REQUIREMENTS = {{
    {packages}
}}

def requirement(name):

    if name in _REQUIREMENTS:
        return _REQUIREMENTS[name]

    name2 = name.replace("_", "-")

    if name2 in _REQUIREMENTS:
        return _REQUIREMENTS[name2]

    fail("Could not find %s or %s in requirements" % (name, name2))


all_requirements = _REQUIREMENTS.values()
"""


def _run(repository_ctx, cmd):
    result = repository_ctx.execute(cmd)

    if result.return_code != 0:
        fail("Failed to execute '%s'\nstderr: %s\nstdout: %s\n" % (" ".join(cmd), result.stderr, result.stdout))

    return result.stdout.strip()

def _install(repository_ctx, certfile, package_name, version=None):
    pip = repository_ctx.which(repository_ctx.attr.pip)
    package = package_name

    if version:
        package += "=={version}".format(version==version)

    cmd = [
        pip,
        "--disable-pip-version-check", 
        "--cert", certfile,
        "install",
        package,
    ]

    _run(repository_ctx, cmd)


def _run_pkginfo(repository_ctx, whl_path, field):
    pkginfo = repository_ctx.which("pkginfo")

    cmd = [
        pkginfo,
        "--single",
        "-f", field,
        whl_path
    ]

    return _run(repository_ctx, cmd)


def _get_whl_name(repository_ctx, whl_path):
    result = _run_pkginfo(repository_ctx, whl_path, "name")
    return result


def _get_whl_dependencies(repository_ctx, whl_path):
    result = _run_pkginfo(repository_ctx, whl_path, "requires_dist")
    requires = [r.strip() for r in result.split(",")]
    deps = [(dep.split(";")[0]).split(" ")[0] for dep in requires]
    return deps


def _dist_info_for_whl_file(whl_file):
    parts = whl_file.basename.split("-")
    return "%s-%s.dist-info" % (parts[0], parts[1])


def _content(repository_ctx, path):
    result = _run(repository_ctx, ["cat", path])
    return result.strip()


def _unzip(repository_ctx, whl_file, unzip_path):
    unzip = repository_ctx.which(repository_ctx.attr.unzip)
    unzip_cmd = [
        unzip,
        "-d", unzip_path,
        whl_file
    ]
    return _run(repository_ctx, unzip_cmd)


def _run_wheel(repository_ctx, requirements, directory, cacert_pem_path):
    pip = repository_ctx.which(repository_ctx.attr.pip)
    cmd = [
        pip,
        "--disable-pip-version-check", 
        "--cert", cacert_pem_path,
        "wheel",
        "-r", requirements,
        "-w", directory
    ]
    return _run(repository_ctx, cmd)


def _process_whl_record(root, record, top_levels):
    srcs = []
    data = []

    for line in record.split("\n"):
        
        parts = line.split(",")

        file = parts[0]
        sha256 = parts[1]
        size = parts[2]

        # TODO: Use sha256 and size for verification

        if file.endswith(".py"):
            srcs.append(file)
        else:
            data.append(file)

    for top_level in [t for t in top_levels if '/' not in t]:
        tlf = root.get_child("%s.py" % top_level)
        if tlf.exists and str(tlf.basename) not in srcs:
            srcs.append(str(tlf.basename))


    return srcs, data


def _pip_import_impl(repository_ctx):
    """Core implementation of pip_import."""

    # One of the things the original piptools.py script did was to extract 
    # cacerts.pem from pip._vendor.requests. This was already bad due to 
    # the access of a private package, but now it is actually broken with
    # later versions of pip. Instead, we'll obtain the cacert.pem file from
    # https://curl.haxx.se/ca/cacert.pem.  
    # (See https://curl.haxx.se/docs/caextract.html).
    cacert_pem_path = repository_ctx.path("").get_child("cacert.pem")
    repository_ctx.download(CACERT_PEM_DOWNLOAD_URL, cacert_pem_path)
    repository_ctx.report_progress("certificates downloaded to %s" % cacert_pem_path)

    # To see the output, pass: quiet=False

    _install(repository_ctx, cacert_pem_path, "pkginfo")
    _install(repository_ctx, cacert_pem_path, "packaging")

    requirements = repository_ctx.path(repository_ctx.attr.requirements)
    directory = repository_ctx.path("")

    repository_ctx.report_progress("Downloading packages specified in %s to %s..." % (requirements, directory))
    _run_wheel(repository_ctx, requirements, directory, cacert_pem_path)

    whl_file_list = [p for p in repository_ctx.path("").readdir() if p.basename.endswith(".whl")]

    whl_files = {
        _get_whl_name(repository_ctx, whl_file): whl_file
        for whl_file in whl_file_list
    }

    whl_deps = {
        whl_name: _get_whl_dependencies(repository_ctx, whl_file)
        for whl_name, whl_file in whl_files.items()
    }

    libraries = []

    for whl_name, whl_file in whl_files.items():
        repository_ctx.report_progress("Processing %s" % whl_name)
        _unzip(repository_ctx, whl_file, repository_ctx.path(""))

        dist_info_path = repository_ctx.path("").get_child(_dist_info_for_whl_file(whl_file))

        top_level_txt = dist_info_path.get_child("top_level.txt")
        top_level_content = _content(repository_ctx, top_level_txt)
        top_levels = [tlc.strip() for tlc in top_level_content.split("\n")]

        record_path = dist_info_path.get_child("RECORD")
        record = _content(repository_ctx, record_path)

        src_list, data_list = _process_whl_record(directory, record, top_levels)
        dep_list = [dep for dep in whl_deps[whl_name] if dep in whl_files]

        srcs = ",\n        ".join(["\"%s\"" % s for s in src_list])
        data = ",\n        ".join(["\"%s\"" % d for d in data_list])
        deps = ", ".join(["\":%s\"" % dep for dep in dep_list])

        library_declaration = _PY_LIBRARY_DECLARATION.format(name=whl_name,
                                                             srcs=srcs,
                                                             data=data,
                                                             dependencies=deps)
        libraries.append(library_declaration)


    repo = str(directory).split("/")[-1]
    packages = {
        whl_name: "@{repo}//:{name}".format(repo=repo, name=whl_name)
        for whl_name in whl_files.keys()
    }
    package_list = ",\n    ".join(["\"{key}\": \"{value}\"".format(key=key, value=value) for key, value in packages.items()])
    library_declarations = "".join(libraries)

    requirements_bzl = repository_ctx.path("").get_child("requirements.bzl")
    requirements_bzl_content = _REQUIREMENTS_BZL.format(packages=package_list)
    build_content = _BUILD.format(library_declarations=library_declarations)

    repository_ctx.report_progress("Writing BUILD file")
    repository_ctx.file("BUILD", build_content)

    repository_ctx.report_progress("Writing requirements.bzl")
    repository_ctx.file(requirements_bzl, requirements_bzl_content)

    repository_ctx.report_progress("")

pip_import = repository_rule(
    attrs = {
        "requirements": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "pip": attr.string(default="pip3.5", doc="Which pip version to use. Defaults to pip3.5."),
        "python": attr.string(default="python3.5", doc="Which python version to use. Defaults to python3.5"),
        "unzip": attr.string(default="unzip", doc="Which unzip tool to use. Defaults to unzip."),
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
