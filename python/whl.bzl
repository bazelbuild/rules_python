# Copyright 2017 Google Inc. All rights reserved.
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
"""A rule for importing .whl files as py_library."""

def _whl_impl(repository_ctx):
  """Core implementation of whl_library."""

  result = repository_ctx.execute([
    repository_ctx.path(repository_ctx.attr._script),
    repository_ctx.path(repository_ctx.attr.whl),
    repository_ctx.attr.requirements,
  ])
  if result.return_code:
    fail("whl_library failed: %s (%s)" % (result.stdout, result.stderr))

whl_library = repository_rule(
    attrs = {
        "whl": attr.label(
            allow_files = True,
            mandatory = True,
            single_file = True,
        ),
        "requirements": attr.string(),
        "_script": attr.label(
            executable = True,
            default = Label("//python:whl.sh"),
            cfg = "host",
        ),
    },
    implementation = _whl_impl,
)
