# Copyright 2023 The Bazel Authors. All rights reserved
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

"Repo rule used by bzlmod extension to create a repo that has a map of Python interpreters and their labels"

load("//python:versions.bzl", "WINDOWS_NAME")
load("//python/private:toolchains_repo.bzl", "get_host_os_arch", "get_host_platform")

_build_file_for_hub_template = """
INTERPRETER_LABELS = {{
{interpreter_labels}
}}
DEFAULT_TOOLCHAIN_NAME = "{default}"
"""

_line_for_hub_template = """\
    "{name}": Label("@{name}_{platform}//:{path}"),
"""

def _hub_repo_impl(rctx):
    (os, arch) = get_host_os_arch(rctx)
    platform = get_host_platform(os, arch)

    rctx.file("BUILD.bazel", "")
    is_windows = (os == WINDOWS_NAME)
    path = "python.exe" if is_windows else "bin/python3"

    interpreter_labels = "\n".join([_line_for_hub_template.format(
        name = name,
        platform = platform,
        path = path,
    ) for name in rctx.attr.toolchains])

    rctx.file(
        "interpreters.bzl",
        _build_file_for_hub_template.format(
            interpreter_labels = interpreter_labels,
            default = rctx.attr.default_toolchain,
        ),
    )

hub_repo = repository_rule(
    doc = """\
This private rule create a repo with a BUILD file that contains a map of interpreter names
and the labels to said interpreters. This map is used to by the interpreter hub extension.
""",
    implementation = _hub_repo_impl,
    attrs = {
        "default_toolchain": attr.string(
            doc = "Name of the default toolchain",
            mandatory = True,
        ),
        "toolchains": attr.string_list(
            doc = "List of the base names the toolchain repo defines.",
            mandatory = True,
        ),
    },
)
