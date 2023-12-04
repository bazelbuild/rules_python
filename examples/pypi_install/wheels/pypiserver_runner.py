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
)

def main():
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        wheelhouse = tmpdir / "wheelhouse"
        wheelhouse.mkdir()

        for wheel in WHEELS:
            shutil.copy(r.Rlocation("rules_python_pypi_install_example/wheels/{}".format(wheel)), wheelhouse)

        sys.argv = [
                # TODO(phil): Finish this.
            "
        pypiserver_main()
