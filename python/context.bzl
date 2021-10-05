"python_context_data rule"

load("//python:providers.bzl", "PythonContextInfo")

_DOC = """python_context_data gathers information about the build configuration.
It is a common dependency of all targets that are sensitive to configuration.
"""

def _impl(ctx):
    return [PythonContextInfo(stamp = ctx.attr.stamp)]

# Modelled after go_context_data in rules_go
# Works around github.com/bazelbuild/bazel/issues/1054
python_context_data = rule(
    implementation = _impl,
    attrs = {
        "stamp": attr.bool(mandatory = True),
    },
    doc = _DOC,
)
