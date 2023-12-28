import unittest
from pathlib import Path

from python import runfiles
from python.pip_install.tools.wheel_installer import wheel


class DepsTest(unittest.TestCase):
    def test_simple(self):
        deps = wheel.Deps("foo", requires_dist=["bar"])

        got = deps.build()

        self.assertIsInstance(got, wheel.FrozenDeps)
        self.assertEqual(["bar"], got.deps)
        self.assertEqual({}, got.deps_select)

    def test_can_add_os_specific_deps(self):
        platforms = {
            "linux_x86_64",
            "osx_x86_64",
            "windows_x86_64",
        }
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "posix_dep; os_name=='posix'",
                "win_dep; os_name=='nt'",
            ],
            platforms=set(wheel.Platform.from_string(platforms)),
        )

        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual(
            {
                "@platforms//os:linux": ["posix_dep"],
                "@platforms//os:osx": ["posix_dep"],
                "@platforms//os:windows": ["win_dep"],
            },
            got.deps_select,
        )

    def test_can_add_platform_specific_deps(self):
        platforms = {
            "linux_x86_64",
            "osx_x86_64",
            "osx_aarch64",
            "windows_x86_64",
        }
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "posix_dep; os_name=='posix'",
                "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
                "win_dep; os_name=='nt'",
            ],
            platforms=set(wheel.Platform.from_string(platforms)),
        )

        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual(
            {
                "osx_aarch64": ["m1_dep", "posix_dep"],
                "@platforms//os:linux": ["posix_dep"],
                "@platforms//os:osx": ["posix_dep"],
                "@platforms//os:windows": ["win_dep"],
            },
            got.deps_select,
        )

    def test_non_platform_markers_are_added_to_common_deps(self):
        platforms = {
            "linux_x86_64",
            "osx_x86_64",
            "osx_aarch64",
            "windows_x86_64",
        }
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "baz; implementation_name=='cpython'",
                "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
            ],
            platforms=set(wheel.Platform.from_string(platforms)),
        )

        got = deps.build()

        self.assertEqual(["bar", "baz"], got.deps)
        self.assertEqual(
            {
                "osx_aarch64": ["m1_dep"],
            },
            got.deps_select,
        )

    def test_self_is_ignored(self):
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "req_dep; extra == 'requests'",
                "foo[requests]; extra == 'ssl'",
                "ssl_lib; extra == 'ssl'",
            ],
            extras={"ssl"},
        )

        got = deps.build()

        self.assertEqual(["bar", "req_dep", "ssl_lib"], got.deps)
        self.assertEqual({}, got.deps_select)

    def test_handle_etils(self):
        # given
        rfiles = runfiles.Create()
        metadata = Path(rfiles.Rlocation("testdata_etils_metadata/file/METADATA"))

        requires_dist = [
            requires.partition(":")[2].strip()
            for requires in [
                line
                for line in metadata.read_text().split("\n")
                if line.startswith("Requires-Dist: ")
            ]
        ]
        deps = wheel.Deps("etils", requires_dist=requires_dist, extras={"all"})

        got = deps.build()
        want = [
            "absl_py",
            "dm_tree",
            "fsspec",
            "gcsfs",
            "importlib_resources",
            "jax",
            "jupyter",
            "mediapy",
            "numpy",
            "packaging",
            "protobuf",
            "s3fs",
            "simple_parsing",
            "tensorflow",
            "tqdm",
            "typing_extensions",
            "zipp",
        ]

        self.assertEqual(want, got.deps)
        self.assertEqual({}, got.deps_select)


class PlatformTest(unittest.TestCase):
    def test_can_get_host(self):
        host = wheel.Platform.host()
        self.assertIsNotNone(host)
        self.assertEqual(1, len(wheel.Platform.from_string("host")))
        self.assertEqual(host, wheel.Platform.from_string("host"))

    def test_can_get_all(self):
        all_platforms = wheel.Platform.all()
        self.assertEqual(15, len(all_platforms))
        self.assertEqual(all_platforms, wheel.Platform.from_string("all"))

    def test_can_get_all_for_os(self):
        linuxes = wheel.Platform.all(wheel.OS.linux)
        self.assertEqual(5, len(linuxes))
        self.assertEqual(linuxes, wheel.Platform.from_string("linux_*"))


if __name__ == "__main__":
    unittest.main()
