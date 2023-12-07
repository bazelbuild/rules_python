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
load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
    "bazel_integration_tests",
    "integration_test_utils",
)

def rules_python_integration_test(name, workspace_path=None, bzlmod=False, tags=None, **kwargs):
    workspace_path = workspace_path or name.removesuffix("_example")
    test_runner = "//tests:simple_test_runner" if bzlmod else "//tests:legacy_test_runner"

    bazel_integration_tests(
        name = name,
        workspace_path = workspace_path,
        test_runner = test_runner,
        bazel_versions = bazel_binaries.versions.all,
        workspace_files = integration_test_utils.glob_workspace_files(workspace_path) + [
            "//:distribution",
        ],
        tags = (tags or []) + [
            # Upstream normally runs the tests with the `exclusive` tag. That
            # tag also implies `local` by default. We don't really need the
            # exclusion feature, but we do need the test to break the sandbox.
            # Replicate that here.
            # https://github.com/bazelbuild/bazel/issues/16871
            "no-sandbox",
            "no-remote",
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
