# std_modules.py is a long-living program that communicates over STDIN and
# STDOUT. STDIN receives module names, one per line. For each module statement
# it evaluates, it outputs true/false for whether the module is part of the
# standard library or not.

import site
import sys


# Don't return any paths, all userland site-packages should be ignored.
def __override_getusersitepackages__():
    return ""


site.getusersitepackages = __override_getusersitepackages__


def is_std_modules(module):
    try:
        __import__(module, globals(), locals(), [], 0)
        return True
    except Exception:
        return False


def main(stdin, stdout):
    for module in stdin:
        module = module.strip()
        # Don't print the boolean directly as it is captilized in Python.
        print(
            "true" if is_std_modules(module) else "false",
            end="\n",
            file=stdout,
        )
        stdout.flush()


if __name__ == "__main__":
    exit(main(sys.stdin, sys.stdout))
