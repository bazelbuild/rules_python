"""This file contains macros to be called during WORKSPACE evaluation.

For historic reasons, pip_repositories() is defined in //python:pip.bzl.
"""
load("//python:pip.bzl", "pip_install")

def py_repositories():
    # buildifier: disable=print
    print("py_repositories is a no-op and is deprecated. You can remove this from your WORKSPACE file")

def py_packaging_repositories(python_interpreter="python3"):
    pip_install(
        name = "rules_python_packaging_deps",
        python_interpreter = python_interpreter,
        requirements = "@rules_python//python:packaging_requirements.txt",
    )
