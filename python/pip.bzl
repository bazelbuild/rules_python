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
"""A rule for importing Python dependencies via requirements.txt."""

def _import_impl(repository_ctx):
  """Core implementation of pip_import."""

  # Add an empty top-level BUILD file.
  repository_ctx.file("BUILD", "")

  result = repository_ctx.execute([
    repository_ctx.path(repository_ctx.attr._script),
    repository_ctx.attr.name,
    repository_ctx.path(repository_ctx.attr.requirements),
    repository_ctx.path("requirements.bzl"),
    repository_ctx.path(""),
  ])
  if result.return_code:
    fail("pip_import failed: %s (%s)" % (result.stdout, result.stderr))

pip_import = repository_rule(
    attrs = {
        "requirements": attr.label(
            allow_files = True,
            mandatory = True,
            single_file = True,
        ),
        "_script": attr.label(
            executable = True,
            default = Label("//python:pip.sh"),
            cfg = "host",
        ),
    },
    implementation = _import_impl,
)

def pip_repositories():
  """Pull in dependencies needed for pulling in pip dependencies.

  A placeholder method that will eventually pull in any dependencies
  needed to install pip dependencies.
  """
  pass
