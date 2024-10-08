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

"pip module extensions for use with bzlmod."

load("//python/private/pypi:extension.bzl", "override_tag", "pypi_attrs", "whl_mod_attrs", _pypi = "pypi")

def _impl(module_ctx):
    _pypi(module_ctx)

    # We default to calling the PyPI index and that will go into the
    # MODULE.bazel.lock file, hence return nothing here.
    return None

def _install_attrs():
    attrs = pypi_attrs()
    attrs.update({
        "extra_index_urls": attr.string_list(
            doc = """\
The extra index URLs to use for downloading wheels using bazel downloader.
Each value is going to be subject to `envsubst` substitutions if necessary.

The indexes must support Simple API as described here:
https://packaging.python.org/en/latest/specifications/simple-repository-api/

This is equivalent to `--extra-index-urls` `pip` option.
""",
            default = [],
        ),
        "index_url": attr.string(
            default = "https://pypi.org/simple",
            doc = """\
The index URL to use for downloading wheels using bazel downloader. This value is going
to be subject to `envsubst` substitutions if necessary.

The indexes must support Simple API as described here:
https://packaging.python.org/en/latest/specifications/simple-repository-api/

In the future this could be defaulted to `https://pypi.org` when this feature becomes
stable.

This is equivalent to `--index-url` `pip` option.
""",
        ),
        "index_url_overrides": attr.string_dict(
            doc = """\
The index URL overrides for each package to use for downloading wheels using
bazel downloader. This value is going to be subject to `envsubst` substitutions
if necessary.

The key is the package name (will be normalized before usage) and the value is the
index URL.

This design pattern has been chosen in order to be fully deterministic about which
packages come from which source. We want to avoid issues similar to what happened in
https://pytorch.org/blog/compromised-nightly-dependency/.

The indexes must support Simple API as described here:
https://packaging.python.org/en/latest/specifications/simple-repository-api/
""",
        ),
    })
    return attrs

pypi = module_extension(
    doc = """\
This extension is used to make dependencies from pypi available.

This is still experimental and may have some API revisions, but it has been
used in production by some projects and the `whl` management should remain
relatively stable.

The extra features that this provides are:
* Contacts the PyPI servers (or private indexes) to get the URLs for the packages.
* Download them using the bazel downloader.
* Setup config settings based on whl filenames so that everything still works
  when host platform is not the same as the target platform.

:::{topic} pypi.install
To use, call `pypi.install()` and specify `hub_name` and your requirements file.
Dependencies will be downloaded and made available in a repo named after the
`hub_name` argument.

Each `pypi.install()` call configures a particular Python version. Multiple calls
can be made to configure different Python versions, and will be grouped by
the `hub_name` argument. This allows the same logical name, e.g. `@pypi//numpy`
to automatically resolve to different, Python version-specific, libraries.
:::

:::{topic} pypi.whl_mods
This tag class is used to help create JSON files to describe modifications to
the BUILD files for wheels.
:::

:::{versionadded} 0.37.0
:::
""",
    implementation = _impl,
    tag_classes = {
        "install": tag_class(
            attrs = _install_attrs(),
            doc = """\
This tag class is used to create a pypi hub and all of the spokes that are part of that hub.
This tag class reuses most of the pypi attributes that are found in
@rules_python//python/pip_install:pip_repository.bzl.
The exception is it does not use the arg 'repo_prefix'.  We set the repository
prefix for the user and the alias arg is always True in bzlmod.
""",
        ),
        "override": override_tag,
        "whl_mods": tag_class(
            attrs = whl_mod_attrs(),
            doc = """\
This tag class is used to create JSON file that are used when calling wheel_builder.py.  These
JSON files contain instructions on how to modify a wheel's project.  Each of the attributes
create different modifications based on the type of attribute. Previously to bzlmod these
JSON files where referred to as annotations, and were renamed to whl_modifications in this
extension.
""",
        ),
    },
)
