"""Rules to verify and update pip-compile locked requirements.txt"""

load("//python:defs.bzl", "py_binary", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")

def compile_pip_requirements(
        name,
        extra_args = [],
        visibility = ["//visibility:private"],
        requirements_in = None,
        requirements_txt = None,
        requirements_linux = None,
        requirements_darwin = None,
        requirements_windows = None,
        tags = None,
        **kwargs):
    """Generates targets for managing pip dependencies with pip-compile.

    By default this rules generates a filegroup named "[name]" which can be included in the data
    of some other compile_pip_requirements rule that references these requirements
    (e.g. with `-r ../other/requirements.txt`).

    It also generates two targets for running pip-compile:

    - validate with `bazel test <name>_test`
    - update with   `bazel run <name>.update`

    Args:
        name: base name for generated targets, typically "requirements"
        extra_args: passed to pip-compile
        visibility: passed to both the _test and .update rules
        requirements_in: file expressing desired dependencies
        requirements_txt: result of "compiling" the requirements.in file
        requirements_linux: File of linux specific resolve output to check validate if requirement.in has changes.
        requirements_darwin: File of darwin specific resolve output to check validate if requirement.in has changes.
        requirements_windows: File of windows specific resolve output to check validate if requirement.in has changes.
        tags: tagging attribute common to all build rules, passed to both the _test and .update rules
        **kwargs: other bazel attributes passed to the "_test" rule
    """
    requirements_in = name + ".in" if requirements_in == None else requirements_in
    requirements_txt = name + ".txt" if requirements_txt == None else requirements_txt

    # "Default" target produced by this macro
    # Allow a compile_pip_requirements rule to include another one in the data
    # for a requirements file that does `-r ../other/requirements.txt`
    native.filegroup(
        name = name,
        srcs = kwargs.pop("data", []) + [requirements_txt],
        visibility = visibility,
    )

    data = [name, requirements_in, requirements_txt] + [f for f in (requirements_linux, requirements_darwin, requirements_windows) if f != None]

    # Use the Label constructor so this is expanded in the context of the file
    # where it appears, which is to say, in @rules_python
    pip_compile = Label("//python/pip_install:pip_compile.py")

    loc = "$(rootpath {})"

    args = [
        loc.format(requirements_in),
        loc.format(requirements_txt),
        # String None is a placeholder for argv ordering.
        loc.format(requirements_linux) if requirements_linux else "None",
        loc.format(requirements_darwin) if requirements_darwin else "None",
        loc.format(requirements_windows) if requirements_windows else "None",
        "//%s:%s.update" % (native.package_name(), name),
    ] + extra_args

    deps = [
        requirement("build"),
        requirement("click"),
        requirement("colorama"),
        requirement("pep517"),
        requirement("pip"),
        requirement("pip_tools"),
        requirement("setuptools"),
        requirement("tomli"),
        requirement("importlib_metadata"),
        requirement("zipp"),
        requirement("more_itertools"),
    ]

    attrs = {
        "args": args,
        "data": data,
        "deps": deps,
        "main": pip_compile,
        "srcs": [pip_compile],
        "tags": tags,
        "visibility": visibility,
    }

    # cheap way to detect the bazel version
    _bazel_version_4_or_greater = "propeller_optimize" in dir(native)

    # Bazel 4.0 added the "env" attribute to py_test/py_binary
    if _bazel_version_4_or_greater:
        attrs["env"] = kwargs.pop("env", {})

    py_binary(
        name = name + ".update",
        **attrs
    )

    timeout = kwargs.pop("timeout", "short")

    py_test(
        name = name + "_test",
        timeout = timeout,
        # kwargs could contain test-specific attributes like size or timeout
        **dict(attrs, **kwargs)
    )
