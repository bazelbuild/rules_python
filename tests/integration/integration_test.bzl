# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""Helpers for running bazel-in-bazel integration tests."""

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_tests",
    "integration_test_utils",
)
load("//python:py_test.bzl", "py_test")

def rules_python_integration_test(
        name,
        workspace_path = None,
        bzlmod = True,
        gazelle_plugin = False,
        tags = None,
        py_main = None,
        **kwargs):
    """Runs a bazel-in-bazel integration test.

    Args:
        name: Name of the test. This gets appended by the bazel version.
        workspace_path: The directory name. Defaults to `name` without the
            `_test` suffix.
        bzlmod: bool, default True. If true, run with bzlmod enabled, otherwise
            disable bzlmod.
        gazelle_plugin: Whether the test uses the gazelle plugin.
        tags: Test tags.
        py_main: Optional `.py` file to run tests using. When specified, a
            python based test runner is used, and this source file is the main
            entry point and responsible for executing tests.
        **kwargs: Passed to the upstream `bazel_integration_tests` rule.
    """
    workspace_path = workspace_path or name.removesuffix("_test")
    if py_main:
        test_runner = name + "_py_runner"
        py_test(
            name = test_runner,
            srcs = [py_main],
            main = py_main,
            deps = [":runner_lib"],
        )
    elif bzlmod:
        if gazelle_plugin:
            test_runner = "//tests/integration:test_runner_gazelle_plugin"
        else:
            test_runner = "//tests/integration:test_runner"
    elif gazelle_plugin:
        test_runner = "//tests/integration:workspace_test_runner_gazelle_plugin"
    else:
        test_runner = "//tests/integration:workspace_test_runner"

    # Because glob expansion happens at loading time, the bazel-* symlinks
    # in the workspaces can recursively expand to tens-of-thousands of entries,
    # which consumes lots of CPU and RAM and can render the system unusable.
    # To help prevent that, cap the size of the glob expansion.
    workspace_files = integration_test_utils.glob_workspace_files(workspace_path)
    if len(workspace_files) > 1000:
        fail("Workspace {} has too many files. This likely means a bazel-* " +
             "symlink is being followed when it should be ignored.")

    # bazel_integration_tests creates a separate file group target of the workspace
    # files for each bazel version, even though the file groups are the same
    # for each one.
    # To avoid that, manually create a single filegroup once and re-use it.
    native.filegroup(
        name = name + "_workspace_files",
        srcs = workspace_files + [
            "//:distribution",
        ],
    )
    kwargs.setdefault("size", "enormous")
    bazel_integration_tests(
        name = name,
        workspace_path = workspace_path,
        test_runner = test_runner,
        bazel_versions = bazel_binaries.versions.all,
        workspace_files = [name + "_workspace_files"],
        # Override the tags so that the `manual` tag isn't applied.
        tags = (tags or []) + [
            # These tests are very heavy weight, so much so that only a couple
            # can be run in parallel without harming their reliability,
            # overall runtime, and the system's stability. Unfortunately,
            # there doesn't appear to be a way to tell Bazel to limit their
            # concurrency, only disable it entirely with exclusive.
            "exclusive",
            # The default_test_runner() assumes it can write to the user's home
            # directory for caching purposes. Give it access.
            "no-sandbox",
            # The CI RBE setup can't successfully run these tests remotely.
            "no-remote-exec",
            # A special tag is used so CI can run them as a separate job.
            "integration-test",
        ],
        **kwargs
    )
