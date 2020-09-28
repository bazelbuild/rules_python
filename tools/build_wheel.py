import os
import sys
import argparse
import shutil
import atexit
import pkgutil
import tempfile

from tools.utils.par_helper import extract_packages

# In case we're running as a PAR archive, extract dependencies
# that aren't happy running as a zipfile.
extract_packages(['pip', 'setuptools', 'wheel'])

# Defeat pip's attempt to mangle sys.path
# fmt: off
saved_sys_path = sys.path
sys.path = sys.path[:]
import pip
import setuptools
import wheel
sys.path = saved_sys_path
# fmt: on


def _augment_import_path(paths):
    paths = [os.path.abspath(p) for p in paths]

    augmented = sys.path[:]
    augmented.extend(paths)

    sys.path = augmented
    os.environ['PYTHONPATH'] = os.pathsep.join(augmented)


def _run_pip(args):
    cert_tmpdir = tempfile.mkdtemp()
    cert_path = os.path.join(cert_tmpdir, "cacert.pem")

    atexit.register(lambda: shutil.rmtree(cert_tmpdir, ignore_errors=True))

    with open(cert_path, "wb") as cert:
        cert.write(pkgutil.get_data("pip._vendor.requests", "cacert.pem"))

    args = ["--isolated", "--disable-pip-version-check", "--cert", cert_path] + args

    return pip.main(args)


def main():
    parser = argparse.ArgumentParser(
        description='Build wheel from source distribution')

    parser.add_argument('--output', action='store',
                        help=('Output folder.'))

    parser.add_argument('--wheels', action='append', default=[],
                        help=('Wheel index paths.'))

    parser.add_argument('--imports', action='append', default=[],
                        help=('Imports index paths.'))

    parser.add_argument('source', action='store',
                        help=('The source distribution folder.'))

    args = parser.parse_args()

    _augment_import_path(args.imports)

    # Build
    pip_args = [
        "wheel",
        "--quiet",
        "--no-cache-dir",
        "--no-index",
        "--no-deps",
        "-w", args.output,
    ]

    pip_args.extend([
        "--find-links=%s" % os.path.abspath(p) for p in args.wheels
    ])

    pip_args.append(args.source)

    return _run_pip(pip_args)


if __name__ == "__main__":
    sys.exit(main())
