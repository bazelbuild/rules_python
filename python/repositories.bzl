"""This file contains macros to be called during WORKSPACE evaluation.

For historic reasons, pip_repositories() is defined in //python:pip.bzl.
"""

def py_repositories():
    """Pull in dependencies needed to use the core Python rules."""
    # At the moment this is a placeholder hook, in that it does not actually
    # pull in any dependencies. Users should still call this function to make
    # it less likely that they need to update their WORKSPACE files, in case
    # this function is changed in the future.
    pass
