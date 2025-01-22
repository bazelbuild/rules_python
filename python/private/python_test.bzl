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

"Python test toolchain module extensions for use with bzlmod."

load("@bazel_features//:features.bzl", "bazel_features")
load("//python/private:py_test_toolchain.bzl", "register_py_test_toolchain")

def _python_test_impl(module_ctx):
    """Implementation of the `coverage` extension.

    Configure the test toolchain for setting coverage resource file.

    """
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            register_py_test_toolchain(
                name = "py_test_toolchain",
                coverage_rc = tag.coveragerc,
                register_toolchains = False,
            )
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        return module_ctx.extension_metadata(reproducible = True)
    else:
        return None

configure = tag_class(
    doc = """Tag class used to register Python toolchains.""",
    attrs = {
        # TODO: Add testrunner and potentially coverage_tool
        "coveragerc": attr.label(
            doc = """Tag class used to register Python toolchains.""",
            mandatory = True,
        ),
    },
)

python_test = module_extension(
    doc = """Bzlmod extension that is used to register test toolchains.  """,
    implementation = _python_test_impl,
    tag_classes = {
        "configure": configure,
    },
)
