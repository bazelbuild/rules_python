"Rules to verify and update pip-compile locked requirements.txt"

load("//python:defs.bzl", "py_binary", "py_test")
load("//python/pip_install:repositories.bzl", "requirement")

def compile_pip_requirements(
        name,
        extra_args = [],
        visibility = ["//visibility:private"],
        requirements_in = None,
        requirements_txt = None,
        tags = None,
        **kwargs):
    """
    Macro creating targets for running pip-compile

    Produce a filegroup by default, named "[name]" which can be included in the data
    of some other compile_pip_requirements rule that references these requirements
    (e.g. with `-r ../other/requirements.txt`)

    Produce two targets for checking pip-compile:

    - validate with `bazel test <name>_test`
    - update with   `bazel run <name>.update`

    Args:
        name: base name for generated targets, typically "requirements"
        extra_args: passed to pip-compile
        visibility: passed to both the _test and .update rules
        requirements_in: file expressing desired dependencies
        requirements_txt: result of "compiling" the requirements.in file
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

    data = [name, requirements_in, requirements_txt]

    # Use the Label constructor so this is expanded in the context of the file
    # where it appears, which is to say, in @rules_python
    pip_compile = Label("//python/pip_install:pip_compile.py")

    loc = "$(rootpath %s)"

    args = [
        loc % requirements_in,
        loc % requirements_txt,
        name + ".update",
    ] + extra_args

    deps = [
        requirement("click"),
        requirement("pip"),
        requirement("pip_tools"),
        requirement("setuptools"),
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
