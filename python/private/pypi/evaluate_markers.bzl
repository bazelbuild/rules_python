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

"""A simple function that evaluates markers using a python interpreter."""

load(":deps.bzl", "record_files")
load(":pep508_env.bzl", "env", _platform_from_str = "platform_from_str")
load(":pep508_evaluate.bzl", "evaluate")
load(":pep508_req.bzl", _req = "requirement")

# Used as a default value in a rule to ensure we fetch the dependencies.
SRCS = [
    # When the version, or any of the files in `packaging` package changes,
    # this file will change as well.
    record_files["pypi__packaging"],
    Label("//python/private/pypi/requirements_parser:resolve_target_platforms.py"),
    Label("//python/private/pypi/whl_installer:platform.py"),
]

def evaluate_markers(requirements):
    """Return the list of supported platforms per requirements line.

    Args:
        requirements: dict[str, list[str]] of the requirement file lines to evaluate.

    Returns:
        dict of string lists with target platforms
    """
    ret = {}
    for req_string, platforms in requirements.items():
        req = _req(req_string)
        for platform in platforms:
            if evaluate(req.marker, env = env(_platform_from_str(platform, None))):
                ret.setdefault(req_string, []).append(platform)

    return ret
