load(":wrapper.bzl", "py_wrapper")

# A data file target that contains either "FOO2" or "FOO3", depending on the
# Python version.
filegroup(
    name = "foo",
    srcs = select({
        "@bazel_tools//tools/python:PY2": ["foo2.txt"],
        "@bazel_tools//tools/python:PY3": ["foo3.txt"],
    }),
)

# A target that wraps foo while guaranteeing it's built for PY2.
py_wrapper(
    name = "foo_wrapped2",
    version = "PY2",
    wrapped = ":foo",
)

# A target that wraps foo while guaranteeing it's built for PY3.
py_wrapper(
    name = "foo_wrapped3",
    version = "PY3",
    wrapped = ":foo",
)

# A binary that prints its Python version and the content of its foo data dep.
py_binary(
    name = "bar",
    srcs = ["bar.py"],
    
    # Uncomment exactly one data attr line.
    data = [":foo_wrapped2"],
    # data = [":foo_wrapped3"],
    
    # Our own Python version doesn't matter since it's overwritten by the
    # transition.
    python_version = "PY2",
    deps = ["@bazel_tools//tools/python/runfiles"],
)
