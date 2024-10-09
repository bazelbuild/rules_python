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

load(":extension.bzl", "override_tag", "pypi", "pypi_attrs", "whl_mod_attrs")

def _parse_attrs():
    attrs = pypi_attrs()
    attrs.update({
        # TODO @aignas 2024-10-08: to be removed in 1.0.0
        "experimental_extra_index_urls": attr.string_list(
            doc = "Ignored, please use {bzl:obj}`pypi.install` instead",
        ),
        "experimental_index_url": attr.string(
            doc = "Ignored, please use {bzl:obj}`pypi.install` instead",
        ),
        "experimental_index_url_overrides": attr.string_dict(
            doc = "Ignored, please use {bzl:obj}`pypi.install` instead",
        ),
    })
    return dict(sorted(attrs.items()))

pip = module_extension(
    doc = """\
This extension is used to make dependencies from pip available.

:::{seealso}
We are building a next generation replacement for this extension which:
* Contacts the PyPI servers (or private indexes) to get the URLs for the packages.
* Download them using the bazel downloader.
* Setup config settings based on whl filenames so that everything still works
  when host platform is not the same as the target platform.

If you need any of the features above, consider using {bzl:obj}`pypi.install` instead.
:::

:::{topic} pip.parse
To use, call `pip.parse()` and specify `hub_name` and your requirements file.
Dependencies will be downloaded and made available in a repo named after the
`hub_name` argument.

Each `pip.parse()` call configures a particular Python version. Multiple calls
can be made to configure different Python versions, and will be grouped by
the `hub_name` argument. This allows the same logical name, e.g. `@pip//numpy`
to automatically resolve to different, Python version-specific, libraries.
:::

:::{topic} pip.whl_mods
This tag class is used to help create JSON files to describe modifications to
the BUILD files for wheels.
:::
""",
    implementation = pypi,
    tag_classes = {
        "override": override_tag,
        "parse": tag_class(
            attrs = _parse_attrs(),
            doc = """\
This tag class is used to create a pip hub and all of the spokes that are part of that hub.
This tag class reuses most of the pip attributes that are found in {rule}`pip_repository`.
The exception is it does not use the arg 'repo_prefix'.  We set the repository
prefix for the user and the alias arg is always True in bzlmod.
""",
        ),
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
