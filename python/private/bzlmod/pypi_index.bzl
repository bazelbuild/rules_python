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
load("//python/private:auth.bzl", "get_auth")
load("//python/private:envsubst.bzl", "envsubst")
load(
    "//python/private:pypi_index.bzl",
    "create_spoke_repos",
    "get_packages_from_requirements",
    "pypi_index_hub",
)

_PYPI_INDEX = "pypi_index"

def _impl(module_ctx):
    simpleapi_srcs = {}
    for mod in module_ctx.modules:
        for reqs in mod.tags.add_requirements:
            env_vars = ["PIP_INDEX_URL"]
            index_url = envsubst(
                reqs.index_url,
                env_vars,
                module_ctx.getenv if hasattr(module_ctx, "getenv") else module_ctx.os.environ.get,
            )
            requirements_files = [module_ctx.read(module_ctx.path(src)) for src in reqs.srcs]
            sources = get_packages_from_requirements(requirements_files)
            for pkg, want_shas in sources.simpleapi.items():
                entry = simpleapi_srcs.setdefault(pkg, {"urls": {}, "want_shas": {}})
                entry["urls"]["{}/{}/".format(index_url.rstrip("/"), pkg)] = True
                entry["want_shas"].update(want_shas)

    download_kwargs = {}
    if bazel_features.external_deps.download_has_block_param:
        download_kwargs["block"] = False

    downloads = {}
    for pkg, args in simpleapi_srcs.items():
        output = module_ctx.path("{}/{}.html".format(_PYPI_INDEX, pkg))
        all_urls = list(args["urls"].keys())
        downloads[pkg] = struct(
            out = output,
            urls = all_urls,
            download = module_ctx.download(
                url = all_urls,
                output = output,
                auth = get_auth(
                    # Simulate the repository_ctx so that `get_auth` works.
                    struct(
                        os = module_ctx.os,
                        path = module_ctx.path,
                        read = module_ctx.read,
                    ),
                    all_urls,
                ),
                **download_kwargs
            ),
        )

    repos = {}
    for pkg, args in simpleapi_srcs.items():
        download = downloads[pkg]
        result = download.download
        if download_kwargs.get("block") == False:
            result = result.wait()

        if not result.success:
            fail("Failed to download from {}: {}".format(download.urls, result))

        repos.update(
            create_spoke_repos(
                simple_api_urls = download.urls,
                pkg = pkg,
                html_contents = module_ctx.read(download.out),
                want_shas = args["want_shas"],
                prefix = _PYPI_INDEX,
            ),
        )

    pypi_index_hub(
        name = _PYPI_INDEX,
        repos = repos,
    )

pypi_index = module_extension(
    doc = "",
    implementation = _impl,
    tag_classes = {
        "add_requirements": tag_class(
            attrs = {
                "extra_index_urls": attr.string_list(
                    doc = """\
Extra indexes to read for the given files. The indexes should support introspection via HTML simple API standard.

See https://packaging.python.org/en/latest/specifications/simple-repository-api/
""",
                ),
                "index_url": attr.string(
                    doc = """\
By default rules_python will use the env variable value of PIP_INDEX_URL if present.
""",
                    default = "${PIP_INDEX_URL:-https://pypi.org/simple}",
                ),
                "srcs": attr.label_list(),
            },
        ),
    },
)
