"""Sets up rules_python repository deps for WORKSPACE users"""

load("@bazel_features//:deps.bzl", "bazel_features_deps")

def py_repositories_deps():
    bazel_features_deps()
