load("@pip_parsed_deps//:requirements.bzl", "entry_point", "requirement")
load("@rules_python//python:defs.bzl", "py_binary", "py_test")
load("@rules_python//python/pip_install:requirements.bzl", "compile_pip_requirements")

# Toolchain setup, this is optional.
# Demonstrate that we can use the same python interpreter for the toolchain and executing pip in pip install (see WORKSPACE).
#
#load("@rules_python//python:defs.bzl", "py_runtime_pair")
#
#py_runtime(
#    name = "python3_runtime",
#    files = ["@python_interpreter//:files"],
#    interpreter = "@python_interpreter//:python_bin",
#    python_version = "PY3",
#    visibility = ["//visibility:public"],
#)
#
#py_runtime_pair(
#    name = "my_py_runtime_pair",
#    py2_runtime = None,
#    py3_runtime = ":python3_runtime",
#)
#
#toolchain(
#    name = "my_py_toolchain",
#    toolchain = ":my_py_runtime_pair",
#    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
#)
# End of toolchain setup.

py_binary(
    name = "main",
    srcs = ["main.py"],
    deps = [
        requirement("requests"),
    ],
)

py_test(
    name = "test",
    srcs = ["test.py"],
    deps = [":main"],
)

# For pip dependencies which have entry points, the `entry_point` macro can be
# used from the generated `pip_install` repository to access a runnable binary.
alias(
    name = "wheel",
    # If `pkg` and `script` are the same, passing a single string to
    # `entry_point` would work as well: `entry_point("wheel")`
    actual = entry_point(
        pkg = "wheel",
        script = "wheel",
    ),
)

py_test(
    name = "entry_point_test",
    srcs = ["entry_point_test.py"],
    data = [":wheel"],
)

# This rule adds a convenient way to update the requiremenst file.
compile_pip_requirements(
    name = "requirements",
    extra_args = ["--allow-unsafe"],
    requirements_in = "requirements.txt",
    requirements_txt = "requirements_lock.txt",
)
