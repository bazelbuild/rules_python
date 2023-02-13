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

"Define a rule for running bazel test under Bazel"

load("//:version.bzl", "SUPPORTED_BAZEL_VERSIONS", "bazel_version_to_binary_label")
load("//python:defs.bzl", "py_test")

BAZEL_BINARY = bazel_version_to_binary_label(SUPPORTED_BAZEL_VERSIONS[0])

_ATTRS = {
    "bazel_binary": attr.label(
        default = BAZEL_BINARY,
        doc = """The bazel binary files to test against.

It is assumed by the test runner that the bazel binary is found at label_workspace/bazel (wksp/bazel.exe on Windows)""",
    ),
    "bazel_commands": attr.string_list(
        default = ["info", "test --test_output=errors ..."],
        doc = """The list of bazel commands to run.

Note that if a command contains a bare `--` argument, the --test_arg passed to Bazel will appear before it.
""",
    ),
    "bzlmod": attr.bool(
        default = False,
        doc = """Whether the test uses bzlmod.""",
    ),
    "workspace_files": attr.label(
        doc = """A filegroup of all files in the workspace-under-test necessary to run the test.""",
    ),
}

def _config_impl(ctx):
    if len(SUPPORTED_BAZEL_VERSIONS) > 1:
        fail("""
        bazel_integration_test doesn't support multiple Bazel versions to test against yet.
        """)
    if len(ctx.files.workspace_files) == 0:
        fail("""
No files were found to run under integration testing. See comment in /.bazelrc.
You probably need to run 
    tools/bazel_integration_test/update_deleted_packages.sh
""")

    # Serialize configuration file for test runner
    config = ctx.actions.declare_file("%s.json" % ctx.attr.name)
    ctx.actions.write(
        output = config,
        content = """
{{
    "workspaceRoot": "{TMPL_workspace_root}",
    "bazelBinaryWorkspace": "{TMPL_bazel_binary_workspace}",
    "bazelCommands": [ {TMPL_bazel_commands} ],
    "bzlmod": {TMPL_bzlmod}
}}
""".format(
            TMPL_workspace_root = ctx.files.workspace_files[0].dirname,
            TMPL_bazel_binary_workspace = ctx.attr.bazel_binary.label.workspace_name,
            TMPL_bazel_commands = ", ".join(["\"%s\"" % s for s in ctx.attr.bazel_commands]),
            TMPL_bzlmod = str(ctx.attr.bzlmod).lower(),
        ),
    )

    return [DefaultInfo(
        files = depset([config]),
        runfiles = ctx.runfiles(files = [config]),
    )]

_config = rule(
    implementation = _config_impl,
    doc = "Configures an integration test that runs a specified version of bazel against an external workspace.",
    attrs = _ATTRS,
)

def bazel_integration_test(name, override_bazel_version = None, bzlmod = False, dirname = None, **kwargs):
    """Wrapper macro to set default srcs and run a py_test with config

    Args:
        name: name of the resulting py_test
        override_bazel_version: bazel version to use in test
        bzlmod: whether the test uses bzlmod
        dirname: the directory name of the test. Defaults to value of `name` after trimming the `_example` suffix.
        **kwargs: additional attributes like timeout and visibility
    """

    # By default, we assume sources for "pip_example" are in examples/pip/**/*
    dirname = dirname or name[:-len("_example")]
    native.filegroup(
        name = "_%s_sources" % name,
        srcs = native.glob(
            ["%s/**/*" % dirname],
            exclude = ["%s/bazel-*/**" % dirname],
        ),
    )
    workspace_files = kwargs.pop("workspace_files", "_%s_sources" % name)

    bazel_binary = BAZEL_BINARY if not override_bazel_version else bazel_version_to_binary_label(override_bazel_version)
    _config(
        name = "_%s_config" % name,
        workspace_files = workspace_files,
        bazel_binary = bazel_binary,
        bzlmod = bzlmod,
    )

    tags = kwargs.pop("tags", [])
    tags.append("integration-test")

    py_test(
        name = name,
        srcs = [Label("//tools/bazel_integration_test:test_runner.py")],
        main = "test_runner.py",
        args = [native.package_name() + "/_%s_config.json" % name],
        deps = [Label("//python/runfiles")],
        data = [
            bazel_binary,
            "//:distribution",
            "_%s_config" % name,
            workspace_files,
        ],
        tags = tags,
        **kwargs
    )
