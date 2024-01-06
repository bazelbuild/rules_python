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

def rules_python_integration_test(
        name,
        workspace_path = None,
        bzlmod = False,
        gazelle_plugin = False,
        tags = None,
        **kwargs):
    """Runs a bazel-in-bazel integration test.

    Args:
        name: Name of the test. This gets appended by the bazel version.
        workspace_path: The directory name. Defaults to `name` without the
            `_example` suffix.
        bzlmod: Whether to use bzlmod. Defaults to using WORKSPACE.
        gazelle_plugin: Whether the test uses the gazelle plugin.
        tags: Test tags.
        **kwargs: Passed to the upstream `bazel_integration_tests` rule.
    """
    workspace_path = workspace_path or name.removesuffix("_example")
    if bzlmod:
        if gazelle_plugin:
            test_runner = "//tests/integration:test_runner_gazelle_plugin"
        else:
            test_runner = "//tests/integration:test_runner"
    elif gazelle_plugin:
        test_runner = "//tests/integration:workspace_test_runner_gazelle_plugin"
    else:
        test_runner = "//tests/integration:workspace_test_runner"

    bazel_integration_tests(
        name = name,
        workspace_path = workspace_path,
        test_runner = test_runner,
        bazel_versions = bazel_binaries.versions.all,
        workspace_files = integration_test_utils.glob_workspace_files(workspace_path) + [
            "//:distribution",
        ],
        tags = (tags or []) + [
            # Upstream normally runs the tests with the `exclusive` tag.
            # Duplicate that here. There's an argument to be made that we want
            # these to be run in parallel, but it has the potential to
            # overwhelm a system.
            "exclusive",
            # The default_test_runner() assumes it can write to the user's home
            # directory for caching purposes. Give it access.
            "no-sandbox",
            # The CI RBE setup can't successfully run these tests remotely.
            "no-remote-exec",
        ],
        **kwargs
    )

def rules_python_integration_test_suite(name, tests):
    """Exposes a test_suite for the specified rules_python_integration_test's.

    The upstream bazel_integration_tests tags the tests as `manual` so we have
    to wrap those tests in a test_suite().
    """
    native.test_suite(
        name = "integration_tests",
        tests = [
            test
            for test_label in tests
            for test in integration_test_utils.bazel_integration_test_names(
                test_label,
                bazel_binaries.versions.all,
            )
        ],
    )
