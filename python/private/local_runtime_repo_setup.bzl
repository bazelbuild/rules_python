load("@bazel_skylib//lib:selects.bzl", "selects")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_python//python:py_runtime.bzl", "py_runtime")
load("@rules_python//python:py_runtime_pair.bzl", "py_runtime_pair")
load("@rules_python//python/cc:py_cc_toolchain.bzl", "py_cc_toolchain")
load("@rules_python//python/private:py_exec_tools_toolchain.bzl", "py_exec_tools_toolchain")

_PYTHON_VERSION_FLAG = Label("@rules_python//python/config_settings:python_version")

def define_local_runtime_toolchain_impl(
        name,
        lib_ext,
        major,
        minor,
        micro,
        interpreter_path,
        implementation_name,
        os):
    major_minor = "{}.{}".format(major, minor)
    major_minor_micro = "{}.{}".format(major_minor, micro)

    cc_library(
        name = "_python_headers",
        # NOTE: Keep in sync with watch_tree() called in local_runtime_repo
        srcs = native.glob(["include/**/*.h"]),
        includes = ["include"],
    )

    cc_library(
        name = "_libpython",
        # Don't use a recursive glob because the lib/ directory usually contains
        # a subdirectory of the stdlib -- lots of unrelated files
        srcs = native.glob([
            "lib/*{}".format(lib_ext),  # Match libpython*.so
            "lib/*{}*".format(lib_ext),  # Also match libpython*.so.1.0
        ]),
        hdrs = [":_python_headers"],
    )

    py_runtime(
        name = "_py3_runtime",
        interpreter_path = interpreter_path,
        python_version = "PY3",
        interpreter_version_info = {
            "major": major,
            "minor": minor,
            "micro": micro,
        },
        implementation_name = implementation_name,
    )

    py_runtime_pair(
        name = "python_runtimes",
        py2_runtime = None,
        py3_runtime = ":_py3_runtime",
        visibility = ["//visibility:public"],
    )

    py_exec_tools_toolchain(
        name = "py_exec_tools_toolchain",
        visibility = ["//visibility:public"],
    )

    py_cc_toolchain(
        name = "py_cc_toolchain",
        headers = ":_python_headers",
        libs = ":_libpython",
        python_version = major_minor_micro,
        visibility = ["//visibility:public"],
    )

    native.alias(
        name = "os",
        # Call Label() to force the string to evaluate in the context of
        # rules_python, not the calling BUILD-file code. This is because
        # the value is an `@platforms//foo` string, which @rules_python has
        # visibility to, but the calling repo may not.
        actual = Label(os),
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "_is_major_minor",
        flag_values = {
            _PYTHON_VERSION_FLAG: major_minor,
        },
    )
    native.config_setting(
        name = "_is_major_minor_micro",
        flag_values = {
            _PYTHON_VERSION_FLAG: major_minor_micro,
        },
    )
    selects.config_setting_group(
        name = "is_matching_python_version",
        match_any = [
            ":_is_major_minor",
            ":_is_major_minor_micro",
        ],
        visibility = ["//visibility:public"],
    )
