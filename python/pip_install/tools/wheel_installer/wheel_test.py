import unittest

from python.pip_install.tools.wheel_installer import wheel


class DepsTest(unittest.TestCase):
    def test_simple(self):
        deps = wheel.Deps("foo")
        deps.add("bar")

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
            "foo", platforms={wheel.Platform.from_string(p) for p in platforms}
        )
        deps.add(
            "bar",
            "posix_dep; os_name=='posix'",
            "win_dep; os_name=='nt'",
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
            "foo", platforms={wheel.Platform.from_string(p) for p in platforms}
        )
        deps.add(
            "bar",
            "posix_dep; os_name=='posix'",
            "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
            "win_dep; os_name=='nt'",
        )

        got = deps.build("foo")

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
            "foo", platforms={wheel.Platform.from_string(p) for p in platforms}
        )
        deps.add(
            "bar",
            "baz; implementation_name=='cpython'",
            "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
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
        deps = wheel.Deps("foo", extras={"ssl"})
        deps.add(
            "bar",
            "req_dep; extra == 'requests'",
            "foo[requests]; extra == 'ssl'",
            "ssl_lib; extra == 'ssl'",
        )

        got = deps.build()

        self.assertEqual(["bar", "req_dep", "ssl_lib"], got.deps)
        self.assertEqual({}, got.deps_select)

    def test_handle_etils(self):
        deps = wheel.Deps("etils", extras={"all"})
        requires = """
etils[array-types] ; extra == "all"
etils[eapp] ; extra == "all"
etils[ecolab] ; extra == "all"
etils[edc] ; extra == "all"
etils[enp] ; extra == "all"
etils[epath] ; extra == "all"
etils[epath-gcs] ; extra == "all"
etils[epath-s3] ; extra == "all"
etils[epy] ; extra == "all"
etils[etqdm] ; extra == "all"
etils[etree] ; extra == "all"
etils[etree-dm] ; extra == "all"
etils[etree-jax] ; extra == "all"
etils[etree-tf] ; extra == "all"
etils[enp] ; extra == "array-types"
pytest ; extra == "dev"
pytest-subtests ; extra == "dev"
pytest-xdist ; extra == "dev"
pyink ; extra == "dev"
pylint>=2.6.0 ; extra == "dev"
chex ; extra == "dev"
torch ; extra == "dev"
optree ; extra == "dev"
dataclass_array ; extra == "dev"
sphinx-apitree[ext] ; extra == "docs"
etils[dev,all] ; extra == "docs"
absl-py ; extra == "eapp"
simple_parsing ; extra == "eapp"
etils[epy] ; extra == "eapp"
jupyter ; extra == "ecolab"
numpy ; extra == "ecolab"
mediapy ; extra == "ecolab"
packaging ; extra == "ecolab"
etils[enp] ; extra == "ecolab"
etils[epy] ; extra == "ecolab"
etils[epy] ; extra == "edc"
numpy ; extra == "enp"
etils[epy] ; extra == "enp"
fsspec ; extra == "epath"
importlib_resources ; extra == "epath"
typing_extensions ; extra == "epath"
zipp ; extra == "epath"
etils[epy] ; extra == "epath"
gcsfs ; extra == "epath-gcs"
etils[epath] ; extra == "epath-gcs"
s3fs ; extra == "epath-s3"
etils[epath] ; extra == "epath-s3"
typing_extensions ; extra == "epy"
absl-py ; extra == "etqdm"
tqdm ; extra == "etqdm"
etils[epy] ; extra == "etqdm"
etils[array_types] ; extra == "etree"
etils[epy] ; extra == "etree"
etils[enp] ; extra == "etree"
etils[etqdm] ; extra == "etree"
dm-tree ; extra == "etree-dm"
etils[etree] ; extra == "etree-dm"
jax[cpu] ; extra == "etree-jax"
etils[etree] ; extra == "etree-jax"
tensorflow ; extra == "etree-tf"
etils[etree] ; extra == "etree-tf"
etils[ecolab] ; extra == "lazy-imports"
"""

        deps.add(*requires.strip().split("\n"))

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
    def test_platform_from_string(self):
        tests = {
            "win_amd64": "windows_x86_64",
            "macosx_10_9_arm64": "osx_aarch64",
            "manylinux1_i686.manylinux_2_17_i686": "linux_x86_32",
            "musllinux_1_1_ppc64le": "linux_ppc",
        }

        for give, want in tests.items():
            with self.subTest(give=give, want=want):
                self.assertEqual(
                    wheel.Platform.from_string(want),
                    wheel.Platform.from_tag(give),
                )


if __name__ == "__main__":
    unittest.main()
