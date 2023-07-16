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

"""entry_point macro implementation for bzlmod. PRIVATE USE ONLY.

NOTE(2023-07-11): We cannot set the visibility of this utility function, because the hub
repo needs to be able to access this.
"""

load("//python/private:version_label.bzl", "version_label")

def entry_point(*, pkg, packages, default_version, tmpl, script = None):
    """Return an entry_point script dictionary for a select statement.

    PRIVATE USE ONLY.

    Args:
        pkg: the PyPI package name (e.g. "pylint").
        script: the script name to use (e.g. "epylint"), defaults to the `pkg` arg.
        packages: the mapping of PyPI packages to python versions that are supported.
        default_version: the default Python version.
        tmpl: the template that will be interpolated by this function. The
            following keys are going to be replaced: 'version_label', 'pkg' and
            'script'.

    Returns:
        A dict that can be used in select statement or None if the pkg is not
        in the supplied packages dictionary.
    """
    if not script:
        script = pkg

    if pkg not in packages:
        # This is an error case, the caller should execute 'fail' and we are not doing it because
        # we want easier testability.
        return None

    selects = {}
    default = ""
    for full_version in packages[pkg]:
        # Label() is called to evaluate this in the context of rules_python, not the pip repo
        condition = str(Label("//python/config_settings:is_python_{}".format(full_version)))

        entry_point = tmpl.format(
            version_label = version_label(full_version),
            pkg = pkg,
            script = script,
        )

        if full_version == default_version:
            default = entry_point
        else:
            selects[condition] = entry_point

    if default:
        selects["//conditions:default"] = default

    return selects
