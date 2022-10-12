load("//tools/bazel_integration_test:bazel_integration_test.bzl", "bazel_integration_test")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

bazel_integration_test(
    name = "pip_repository_entry_points_example",
    timeout = "long",
    # The dependencies needed for this test are not cross-platform: https://github.com/bazelbuild/rules_python/issues/260
    tags = ["fix-windows"],
)
