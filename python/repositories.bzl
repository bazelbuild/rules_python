"""This file contains macros to be called during WORKSPACE evaluation.

For historic reasons, pip_repositories() is defined in //python:pip.bzl.
"""

def py_repositories():
    # buildifier: disable=print
    print("py_repositories is a no-op and is deprecated. You can remove this from your WORKSPACE file")
