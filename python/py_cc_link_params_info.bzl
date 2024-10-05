"""Public entry point for PyCcLinkParamsInfo."""

load("@rules_python_internal//:rules_python_config.bzl", "config")
load("//python/private/common:providers.bzl", _starlark_PyCcLinkParamsProvider = "PyCcLinkParamsProvider")

_PyCcLinkParamsProvider = getattr(bazel_features.globals, "PyCcLinkParamsProvider", None)
PyCcLinkParamsInfo = _starlark_PyCcLinkParamsProvider if config.enable_pystar or _PyCcLinkParamsProvider == None else PyCcLinkParamsProvider
