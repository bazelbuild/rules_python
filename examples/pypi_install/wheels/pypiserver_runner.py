import shutil
import sys
import tempfile
from pathlib import Path

from pypiserver.__main__ import main as pypiserver_main

from python.runfiles import runfiles

r = runfiles.Create()

WHEELS = (
    "pkg_a-1.0-py3-none-any.whl",
    "pkg_b-1.1-py3-none-any.whl",
    "pkg_c-2.0-py3-none-any.whl",
    "pkg_d-3.0-py3-none-any.whl",
    "pkg_e-4.0-py3-none-any.whl",
)

def main():
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        wheelhouse = tmpdir / "wheelhouse"
        wheelhouse.mkdir()

        for wheel in WHEELS:
            shutil.copy(r.Rlocation("rules_python_pypi_install_example/wheels/{}".format(wheel)), wheelhouse)

        sys.argv = [
            "pypiserver",
            "run",
            "-p",
            "8989",
            str(wheelhouse),
        ]
        print("Running: " + " ".join(sys.argv))
        pypiserver_main()


if __name__ == "__main__":
    sys.exit(main())
