"py_library.bzl is a custom macro that wraps py_library and py_wheel"

load("@rules_python//python:defs.bzl", _py_library = "py_library")
load("@rules_python//python:packaging.bzl", "py_wheel")
load(":py_package.bzl", "py_package")

def py_library(**kwargs):
    """the py_library macro wraps py_library to provide a wheel for each library python rule

    Args:
        **kwargs: the kwargs dict
    """
    name = kwargs.pop("name")
    deps = kwargs.pop("deps", [])
    wheel_name = name + ".whl"
    package_name = name + ".pkg"

    _py_library(
        name = name,
        deps = deps,
        **kwargs
    )

    py_package(
        name = package_name,
        deps = [name] + deps,
    )

    py_wheel(
        name = wheel_name,
        version = "$(wheel_version)",  # assigned by bazel flag --define=wheel_version=0.0.0
        python_tag = "py3",
        distribution = native.package_name().replace("/", "_"),
        deps = [package_name],
        visibility = ["//visibility:public"],
    )
