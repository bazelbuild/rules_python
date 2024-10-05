"""Public entry point for PyCcLinkParamsInfo."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_python_internal//:rules_python_config.bzl", "config")
load("//python/private/common:providers.bzl", _starlark_PyCcLinkParamsProvider = "PyCcLinkParamsProvider")

_PyCcLinkParamsProvider = getattr(bazel_features.globals, "PyCcLinkParamsProvider", None)  # buildifier: disable=name-conventions
PyCcLinkParamsInfo = _starlark_PyCcLinkParamsProvider if config.enable_pystar or _PyCcLinkParamsProvider == None else PyCcLinkParamsProvider
