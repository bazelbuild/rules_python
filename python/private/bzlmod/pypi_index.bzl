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

"""
PyPI index reading extension.

This allows us to translate the lock file to URLs and labels, that we can use to set up the
rest of the packages in the hub repos. This is created as a separate repository to allow
`pip.parse` to be used in an isolated mode.

NOTE: for now the repos resulting from this extension are only supposed to be used in the
rules_python repository until this notice is removed.

I want the usage to be:
```starlark
pypi_index = use_extension("@rules_python//python/extensions:pypi_index.bzl", "pypi_index")
pypi_index.from_requirements(
    srcs = [
        "my_requirement",
    ],
)
```

The main index URL can be overriden with an env var PIP_INDEX_URL by default. What is more,
the user should be able to specify specific package locations to be obtained from elsewhere.

The most important thing to support would be to also support local wheel locations, where we
could read all of the wheels from a specific folder and construct the same repo. Like:
```starlark
pypi_index.from_dirs(
    srcs = [
        "my_folder1",
        "my_folder2",
    ],
)
```

The implementation is left for a future PR.

This can be later used by `pip` extension when constructing the `whl_library` hubs by passing
the right `whl_file` to the rule.

This `pypi_index` extension provides labels for reading the `METADATA` from wheels and downloads
metadata only if the Simple API of the PyPI compatible mirror is exposing it. Otherwise, it
falls back to downloading the whl file and then extracting the `METADATA` file so that the users
of the artifacts created by the extension do not have to care about it being any different.
Whilst this may make the downloading of the whl METADATA somewhat slower, because it will be
in the repository cache, it may be a minor hit to the performance.

The presence of this `METADATA` allows us to essentially get the full graph of the dependencies
within a `hub` repo and contract any dependency cycles in the future as is shown in the 
`pypi_install` extension PR.

Whilst this design has been crafted for `bzlmod`, we could in theory just port this back to
WORKSPACE without too many issues.

If you do:
```console
$ bazel query @pypi_index//requests/...
@pypi_index//requests:requests-2.28.2-py3-none-any.whl
@pypi_index//requests:requests-2.28.2-py3-none-any.whl.METADATA
@pypi_index//requests:requests-2.28.2.tar.gz
@pypi_index//requests:requests-2.31.0-py3-none-any.whl
@pypi_index//requests:requests-2.31.0-py3-none-any.whl.METADATA
@pypi_index//requests:requests-2.31.0.tar.gz
```
"""

load("@bazel_features//:features.bzl", "bazel_features")
load("//python/pip_install:requirements_parser.bzl", parse_requirements = "parse")
load("//python/private:auth.bzl", "get_auth")
load("//python/private:envsubst.bzl", "envsubst")
load("//python/private:normalize_name.bzl", "normalize_name")
load("//python/private:text_util.bzl", "render")

def _impl(module_ctx):
    want_packages = {}
    for mod in module_ctx.modules:
        for reqs in mod.tags.add_requirements:
            env_vars = ["PIP_INDEX_URL"]
            index_url = envsubst(
                reqs.index_url,
                env_vars,
                module_ctx.os.environ.get,
            )
            pkgs = _get_packages_from_requirements(module_ctx, reqs.srcs)
            for pkg, want_shas in pkgs.items():
                pkg = normalize_name(pkg)
                entry = want_packages.setdefault(pkg, {"urls": {}, "want_shas": {}})
                entry["urls"]["{}/{}/".format(index_url.rstrip("/"), pkg)] = True
                entry["want_shas"].update(want_shas)

    download_kwargs = {}
    if bazel_features.external_deps.download_has_block_param:
        download_kwargs["block"] = False

    downloads = {}
    outs = {}
    for pkg, args in want_packages.items():
        outs[pkg] = module_ctx.path("pypi_index/{}.html".format(pkg))
        all_urls = list(args["urls"].keys())

        downloads[pkg] = module_ctx.download(
            url = all_urls,
            output = outs[pkg],
            auth = get_auth(
                struct(
                    os = module_ctx.os,
                    path = module_ctx.path,
                    read = module_ctx.read,
                ),
                all_urls,
            ),
            **download_kwargs
        )

    packages = {}
    for pkg, args in want_packages.items():
        result = downloads[pkg]
        if download_kwargs.get("block") == False:
            result = result.wait()

        if not result.success:
            fail(result)

        content = module_ctx.read(outs[pkg])

        # TODO @aignas 2024-03-08: pass in the index urls, so that we can correctly work
        packages[pkg] = _get_packages(args["urls"].keys()[0].rpartition("/")[0], content, args["want_shas"])

    prefix = "pypi_index"

    repos = {}
    for pkg, urls in packages.items():
        for url in urls:
            pkg_name = "{}__{}_{}".format(prefix, pkg, url.sha256)
            _archive_repo(
                name = pkg_name,
                urls = [url.url],
                filename = url.filename,
                sha256 = url.sha256,
            )
            repos[pkg_name] = url.filename

            if url.metadata_sha256:
                _archive_repo(
                    name = pkg_name + ".METADATA",
                    urls = [url.metadata_url],
                    filename = "METADATA",
                    sha256 = url.metadata_sha256,
                )
            elif url.filename.endswith(".whl"):
                _metadata_repo(
                    name = pkg_name + ".METADATA",
                    prefix = prefix,
                    whl = "@{}//{}:{}".format(
                        prefix,
                        pkg_name,
                        url.filename,
                    ),
                )

    _hub(
        name = prefix,
        repo = prefix,
        repos = repos,
    )

def _get_packages_from_requirements(module_ctx, requirements_files):
    want_packages = {}
    for file in requirements_files:
        contents = module_ctx.read(module_ctx.path(file))
        parse_result = parse_requirements(contents)
        for distribution, line in parse_result.requirements:
            # NOTE @aignas 2024-03-08: this only supports Simple API,
            # more complex cases may need to rely on the usual methods.
            #
            # if we don't have `sha256` values then we will not add this
            # to our index.
            want_packages.setdefault(distribution, {}).update({
                # TODO @aignas 2024-03-07: use sets
                sha.strip(): True
                for sha in line.split("--hash=sha256:")[1:]
            })

    return want_packages

def _get_packages(index_url, content, want_shas):
    packages = []
    for line in content.split("<a href=\"")[1:]:
        url, _, tail = line.partition("#sha256=")
        sha256, _, tail = tail.partition("\"")

        if sha256 not in want_shas:
            continue

        maybe_metadata, _, tail = tail.partition(">")
        filename, _, tail = tail.partition("<")

        metadata_marker = "data-core-metadata=\"sha256="
        if metadata_marker in maybe_metadata:
            # Implement https://peps.python.org/pep-0714/
            _, _, tail = maybe_metadata.partition(metadata_marker)
            metadata_sha256, _, _ = tail.partition("\"")
            metadata_url = url + ".metadata"
        else:
            metadata_sha256 = ""
            metadata_url = ""

        packages.append(
            struct(
                filename = filename,
                url = _absolute_urls(index_url, url),
                sha256 = sha256,
                metadata_sha256 = metadata_sha256,
                metadata_url = metadata_url,
            ),
        )

    if len(packages) != len(want_shas):
        fail("Could not get all of the shas")

    return packages

def _absolute_urls(index_url, candidate):
    if not candidate.startswith(".."):
        return candidate

    candidate_parts = candidate.split("..")
    last = candidate_parts[-1]
    for _ in range(len(candidate_parts) - 1):
        index_url, _, _ = index_url.rstrip("/").rpartition("/")

    return "{}/{}".format(index_url, last.strip("/"))

pypi_index = module_extension(
    doc = "",
    implementation = _impl,
    tag_classes = {
        "add_requirements": tag_class(
            attrs = {
                "index_url": attr.string(
                    doc = "We will substitute the env variable value PIP_INDEX_URL if present.",
                    default = "${PIP_INDEX_URL:-https://pypi.org/simple}",
                ),
                "srcs": attr.label_list(),
            },
        ),
    },
)

def _hub_impl(repository_ctx):
    # This is so that calling the following in rules_python works:
    # $ bazel query $pypi_index/... --ignore_dev_dependency
    repository_ctx.file("BUILD.bazel", "")

    if not repository_ctx.attr.repos:
        return

    packages = {}
    for repo, filename in repository_ctx.attr.repos.items():
        head, _, sha256 = repo.rpartition("_")
        _, _, pkg = head.rpartition("__")

        prefix = repository_ctx.name[:-len(repository_ctx.attr.repo)]
        packages.setdefault(pkg, []).append(
            struct(
                sha256 = sha256,
                filename = filename,
                label = str(Label("@@{}{}//:{}".format(prefix, repo, filename))),
            ),
        )

    for pkg, filenames in packages.items():
        # This contains the labels that should be used in the `pip` extension
        # to get the labels that can be used by `whl_library`.
        repository_ctx.file(
            "{}/index.json".format(pkg),
            json.encode(filenames),
        )

        # These labels should be used to be passed to `whl_library`.
        repository_ctx.file(
            "{}/BUILD.bazel".format(pkg),
            "\n\n".join([
                """package(default_visibility = ["//visibility:public"])""",
                """exports_files(["index.json"])""",
            ] + [
                render.alias(
                    name = r.filename,
                    actual = repr(r.label),
                    visibility = ["//visibility:public"],
                )
                for r in filenames
            ] + [
                render.alias(
                    name = r.filename + ".METADATA",
                    actual = repr(r.label.split("//:")[0] + ".METADATA//:METADATA"),
                    visibility = ["//visibility:public"],
                )
                for r in filenames
                if r.filename.endswith(".whl")
            ]),
        )

_hub = repository_rule(
    implementation = _hub_impl,
    attrs = {
        "repo": attr.string(mandatory = True),
        "repos": attr.string_dict(mandatory = True),
    },
)

def _archive_repo_impl(repository_ctx):
    filename = repository_ctx.attr.filename
    if repository_ctx.attr.file:
        repository_ctx.symlink(repository_ctx.path(repository_ctx.attr.file), filename)
    else:
        # Download the wheel using the downloader
        result = repository_ctx.download(
            url = repository_ctx.attr.urls,
            output = filename,
            auth = get_auth(
                repository_ctx,
                repository_ctx.attr.urls,
            ),
        )

        if not result.success:
            fail(result)

    repository_ctx.file("BUILD.bazel", """\
exports_files(
    ["{}"],
    visibility = ["//visibility:public"],
)
""".format(filename))

_archive_repo = repository_rule(
    implementation = _archive_repo_impl,
    attrs = {
        "file": attr.label(mandatory = False),
        "filename": attr.string(mandatory = True),
        "sha256": attr.string(),
        "urls": attr.string_list(),
    },
)

# this allows to work with other implementations of Indexes that do not serve METADATA like PyPI
# or with patched METADATA in patched and re-zipped wheels.
def _metadata_repo_impl(repository_ctx):
    whl_label = repository_ctx.attr.whl
    prefix = repository_ctx.attr.prefix
    if whl_label.repo_name.endswith(prefix):
        # Here we have a hub repo label which we need to rewrite to the thing that the label
        # is pointing to. We can do this because we own everything
        #
        # NOTE @aignas 2024-03-08: if we see restarts, then it could mean that we are not constructing
        # the right label here.
        whl_label = Label("@@{}//:{}".format(repository_ctx.name[:-len(".METADATA")], whl_label.name))

    repository_ctx.symlink(repository_ctx.path(whl_label), "wheel.zip")
    repository_ctx.extract("wheel.zip")

    content = None
    for p in repository_ctx.path(".").readdir():
        if p.basename.endswith(".dist-info"):
            content = repository_ctx.read(p.get_child("METADATA"))
        repository_ctx.delete(p)

    if content == None:
        fail("Could not find a METADATA file")

    repository_ctx.file("METADATA", content)
    repository_ctx.file("BUILD.bazel", """\
exports_files(
    ["METADATA"],
    visibility = ["//visibility:public"],
)
""")

_metadata_repo = repository_rule(
    implementation = _metadata_repo_impl,
    attrs = {
        "prefix": attr.string(),
        "whl": attr.label(),
    },
)
