"""Exercise lazy wheel retention across separate Bazel invocations."""

import functools
import hashlib
import http.server
import threading
import unittest
import zipfile
from pathlib import Path

from tests.integration import runner


class WheelStorageTest(runner.TestCase):
    def setUp(self):
        super().setUp()
        self.wheel = self.repo_root / "pkg-1.0-py3-none-any.whl"
        with zipfile.ZipFile(self.wheel, "w") as wheel:
            wheel.writestr("pkg/__init__.py", "PATCHED = False\n")
            wheel.writestr(
                "pkg-1.0.dist-info/METADATA",
                "Metadata-Version: 2.1\nName: pkg\nVersion: 1.0\n",
            )
            wheel.writestr(
                "pkg-1.0.dist-info/WHEEL",
                "Wheel-Version: 1.0\nRoot-Is-Purelib: true\nTag: py3-none-any\n",
            )
            wheel.writestr("pkg-1.0.dist-info/RECORD", "")
        self.original_wheel = self.wheel.read_bytes()
        (self.repo_root / "wheel.sha256").write_text(
            hashlib.sha256(self.original_wheel).hexdigest()
        )
        handler = functools.partial(
            http.server.SimpleHTTPRequestHandler, directory=str(self.repo_root)
        )
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.addCleanup(server.server_close)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(server.shutdown)
        self.bazel_env["WHEEL_TEST_ADDRESS"] = f"127.0.0.1:{server.server_port}"
        output_base = self.run_bazel("info", "output_base").stdout.strip()
        self.external = Path(output_base) / "external"

    def repositories(self, name):
        return [
            path
            for path in self.external.iterdir()
            if path.is_dir() and path.name.endswith(("+" + name, "~" + name))
        ]

    def repository(self, name):
        repositories = self.repositories(name)
        self.assertEqual(len(repositories), 1, repositories)
        return repositories[0].resolve()

    def assert_runs(self, name, *, patched):
        result = self.run_bazel("run", "//:" + name)
        self.assert_result_matches(result, f"PATCHED={patched}")

    def test_lazy_archive(self):
        self.assert_runs("plain", patched=False)
        extracted = self.repository("plain")
        self.assertEqual(list(extracted.glob("*.whl")), [])
        self.assertEqual(self.repositories("plain_whl"), [])

        self.run_bazel("build", "@plain//:whl", "@plain//:whl_file")
        archive = self.repository("plain_whl") / self.wheel.name
        self.assertEqual(archive.read_bytes(), self.original_wheel)
        self.assertEqual(list(extracted.glob("*.whl")), [])

    def test_matching_and_nonmatching_patches(self):
        self.assert_runs("patched", patched=True)
        patched = self.repository("patched")
        self.assertFalse((patched / self.wheel.name).exists())
        self.assertEqual(self.repositories("patched_whl"), [])
        self.run_bazel("build", "@patched//:whl", "@patched//:whl_file")
        with zipfile.ZipFile(patched / "pkg-1.0+patched-py3-none-any.whl") as wheel:
            self.assertEqual(wheel.read("pkg/__init__.py"), b"PATCHED = True\n")
        self.assertEqual(self.repositories("patched_whl"), [])

        self.assert_runs("nonmatching", patched=False)
        self.assertEqual(list(self.repository("nonmatching").glob("*.whl")), [])
        self.assertEqual(self.repositories("nonmatching_whl"), [])
        self.run_bazel("build", "@nonmatching//:whl")
        archive = self.repository("nonmatching_whl") / self.wheel.name
        self.assertEqual(archive.read_bytes(), self.original_wheel)

    def test_caller_owned_wheel_is_preserved(self):
        for name, patched in [("provided", False), ("provided_patched", True)]:
            with self.subTest(name=name):
                self.assert_runs(name, patched=patched)
                self.run_bazel("build", f"@{name}//:whl", f"@{name}//:whl_file")
                self.assertEqual(self.wheel.read_bytes(), self.original_wheel)
                self.assertFalse((self.repository(name) / self.wheel.name).exists())
                self.assertEqual(self.repositories(name + "_whl"), [])


if __name__ == "__main__":
    unittest.main()
