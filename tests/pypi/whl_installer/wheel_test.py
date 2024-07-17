import unittest
from random import shuffle
from unittest import mock

from python.private.pypi.whl_installer import wheel


class DepsTest(unittest.TestCase):
    def test_simple(self):
        deps = wheel.Deps("foo", requires_dist=["bar"])

        got = deps.build()

        self.assertIsInstance(got, wheel.FrozenDeps)
        self.assertEqual(["bar"], got.deps)
        self.assertEqual({}, got.deps_select)

    def test_can_add_os_specific_deps(self):
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "an_osx_dep; sys_platform=='darwin'",
                "posix_dep; os_name=='posix'",
                "win_dep; os_name=='nt'",
            ],
            platforms={
                wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_64),
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
                wheel.Platform(os=wheel.OS.windows, arch=wheel.Arch.x86_64),
            },
        )

        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual(
            {
                "@platforms//os:linux": ["posix_dep"],
                "@platforms//os:osx": ["an_osx_dep", "posix_dep"],
                "@platforms//os:windows": ["win_dep"],
            },
            got.deps_select,
        )

    def test_can_add_os_specific_deps_with_specific_python_version(self):
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "an_osx_dep; sys_platform=='darwin'",
                "posix_dep; os_name=='posix'",
                "win_dep; os_name=='nt'",
            ],
            platforms={
                wheel.Platform(
                    os=wheel.OS.linux, arch=wheel.Arch.x86_64, minor_version=8
                ),
                wheel.Platform(
                    os=wheel.OS.osx, arch=wheel.Arch.x86_64, minor_version=8
                ),
                wheel.Platform(
                    os=wheel.OS.osx, arch=wheel.Arch.aarch64, minor_version=8
                ),
                wheel.Platform(
                    os=wheel.OS.windows, arch=wheel.Arch.x86_64, minor_version=8
                ),
            },
        )

        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual(
            {
                "@platforms//os:linux": ["posix_dep"],
                "@platforms//os:osx": ["an_osx_dep", "posix_dep"],
                "@platforms//os:windows": ["win_dep"],
            },
            got.deps_select,
        )

    def test_deps_are_added_to_more_specialized_platforms(self):
        got = wheel.Deps(
            "foo",
            requires_dist=[
                "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
                "mac_dep; sys_platform=='darwin'",
            ],
            platforms={
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
            },
        ).build()

        self.assertEqual(
            wheel.FrozenDeps(
                deps=[],
                deps_select={
                    "osx_aarch64": ["m1_dep", "mac_dep"],
                    "@platforms//os:osx": ["mac_dep"],
                },
            ),
            got,
        )

    def test_deps_from_more_specialized_platforms_are_propagated(self):
        got = wheel.Deps(
            "foo",
            requires_dist=[
                "a_mac_dep; sys_platform=='darwin'",
                "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
            ],
            platforms={
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
            },
        ).build()

        self.assertEqual([], got.deps)
        self.assertEqual(
            {
                "osx_aarch64": ["a_mac_dep", "m1_dep"],
                "@platforms//os:osx": ["a_mac_dep"],
            },
            got.deps_select,
        )

    def test_non_platform_markers_are_added_to_common_deps(self):
        got = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "baz; implementation_name=='cpython'",
                "m1_dep; sys_platform=='darwin' and platform_machine=='arm64'",
            ],
            platforms={
                wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_64),
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
                wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
                wheel.Platform(os=wheel.OS.windows, arch=wheel.Arch.x86_64),
            },
        ).build()

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

    def test_self_dependencies_can_come_in_any_order(self):
        deps = wheel.Deps(
            "foo",
            requires_dist=[
                "bar",
                "baz; extra == 'feat'",
                "foo[feat2]; extra == 'all'",
                "foo[feat]; extra == 'feat2'",
                "zdep; extra == 'all'",
            ],
            extras={"all"},
        )

        got = deps.build()

        self.assertEqual(["bar", "baz", "zdep"], got.deps)
        self.assertEqual({}, got.deps_select)

    def test_can_get_deps_based_on_specific_python_version(self):
        requires_dist = [
            "bar",
            "baz; python_version < '3.8'",
            "posix_dep; os_name=='posix' and python_version >= '3.8'",
        ]

        py38_deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=[
                wheel.Platform(
                    os=wheel.OS.linux, arch=wheel.Arch.x86_64, minor_version=8
                ),
            ],
        ).build()
        py37_deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=[
                wheel.Platform(
                    os=wheel.OS.linux, arch=wheel.Arch.x86_64, minor_version=7
                ),
            ],
        ).build()

        self.assertEqual(["bar", "baz"], py37_deps.deps)
        self.assertEqual({}, py37_deps.deps_select)
        self.assertEqual(["bar"], py38_deps.deps)
        self.assertEqual({"@platforms//os:linux": ["posix_dep"]}, py38_deps.deps_select)

    @mock.patch(
        "python.private.pypi.whl_installer.wheel.host_interpreter_minor_version"
    )
    def test_no_version_select_when_single_version(self, mock_host_interpreter_version):
        requires_dist = [
            "bar",
            "baz; python_version >= '3.8'",
            "posix_dep; os_name=='posix'",
            "posix_dep_with_version; os_name=='posix' and python_version >= '3.8'",
            "arch_dep; platform_machine=='x86_64' and python_version >= '3.8'",
        ]
        mock_host_interpreter_version.return_value = 7

        self.maxDiff = None

        deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=[
                wheel.Platform(os=os, arch=wheel.Arch.x86_64, minor_version=minor)
                for minor in [8]
                for os in [wheel.OS.linux, wheel.OS.windows]
            ],
        )
        got = deps.build()

        self.assertEqual(["bar", "baz"], got.deps)
        self.assertEqual(
            {
                "@platforms//os:linux": ["posix_dep", "posix_dep_with_version"],
                "linux_x86_64": ["arch_dep", "posix_dep", "posix_dep_with_version"],
                "windows_x86_64": ["arch_dep"],
            },
            got.deps_select,
        )

    @mock.patch(
        "python.private.pypi.whl_installer.wheel.host_interpreter_minor_version"
    )
    def test_can_get_version_select(self, mock_host_interpreter_version):
        requires_dist = [
            "bar",
            "baz; python_version < '3.8'",
            "baz_new; python_version >= '3.8'",
            "posix_dep; os_name=='posix'",
            "posix_dep_with_version; os_name=='posix' and python_version >= '3.8'",
            "arch_dep; platform_machine=='x86_64' and python_version < '3.8'",
        ]
        mock_host_interpreter_version.return_value = 7

        self.maxDiff = None

        deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=[
                wheel.Platform(os=os, arch=wheel.Arch.x86_64, minor_version=minor)
                for minor in [7, 8, 9]
                for os in [wheel.OS.linux, wheel.OS.windows]
            ],
        )
        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual(
            {
                "//conditions:default": ["baz"],
                "@//python/config_settings:is_python_3.7": ["baz"],
                "@//python/config_settings:is_python_3.8": ["baz_new"],
                "@//python/config_settings:is_python_3.9": ["baz_new"],
                "@platforms//os:linux": ["baz", "posix_dep"],
                "cp37_linux_x86_64": ["arch_dep", "baz", "posix_dep"],
                "cp37_windows_x86_64": ["arch_dep", "baz"],
                "cp37_linux_anyarch": ["baz", "posix_dep"],
                "cp38_linux_anyarch": [
                    "baz_new",
                    "posix_dep",
                    "posix_dep_with_version",
                ],
                "cp39_linux_anyarch": [
                    "baz_new",
                    "posix_dep",
                    "posix_dep_with_version",
                ],
                "linux_x86_64": ["arch_dep", "baz", "posix_dep"],
                "windows_x86_64": ["arch_dep", "baz"],
            },
            got.deps_select,
        )

    @mock.patch(
        "python.private.pypi.whl_installer.wheel.host_interpreter_minor_version"
    )
    def test_deps_spanning_all_target_py_versions_are_added_to_common(
        self, mock_host_version
    ):
        requires_dist = [
            "bar",
            "baz (<2,>=1.11) ; python_version < '3.8'",
            "baz (<2,>=1.14) ; python_version >= '3.8'",
        ]
        mock_host_version.return_value = 8

        deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=wheel.Platform.from_string(["cp37_*", "cp38_*", "cp39_*"]),
        )
        got = deps.build()

        self.assertEqual(["bar", "baz"], got.deps)
        self.assertEqual({}, got.deps_select)

    @mock.patch(
        "python.private.pypi.whl_installer.wheel.host_interpreter_minor_version"
    )
    def test_deps_are_not_duplicated(self, mock_host_version):
        mock_host_version.return_value = 7

        # See an example in
        # https://files.pythonhosted.org/packages/76/9e/db1c2d56c04b97981c06663384f45f28950a73d9acf840c4006d60d0a1ff/opencv_python-4.9.0.80-cp37-abi3-win32.whl.metadata
        requires_dist = [
            "bar >=0.1.0 ; python_version < '3.7'",
            "bar >=0.2.0 ; python_version >= '3.7'",
            "bar >=0.4.0 ; python_version >= '3.6' and platform_system == 'Linux' and platform_machine == 'aarch64'",
            "bar >=0.4.0 ; python_version >= '3.9'",
            "bar >=0.5.0 ; python_version <= '3.9' and platform_system == 'Darwin' and platform_machine == 'arm64'",
            "bar >=0.5.0 ; python_version >= '3.10' and platform_system == 'Darwin'",
            "bar >=0.5.0 ; python_version >= '3.10'",
            "bar >=0.6.0 ; python_version >= '3.11'",
        ]

        deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=wheel.Platform.from_string(["cp37_*", "cp310_*"]),
        )
        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual({}, got.deps_select)

    @mock.patch(
        "python.private.pypi.whl_installer.wheel.host_interpreter_minor_version"
    )
    def test_deps_are_not_duplicated_when_encountering_platform_dep_first(
        self, mock_host_version
    ):
        mock_host_version.return_value = 7

        # Note, that we are sorting the incoming `requires_dist` and we need to ensure that we are not getting any
        # issues even if the platform-specific line comes first.
        requires_dist = [
            "bar >=0.4.0 ; python_version >= '3.6' and platform_system == 'Linux' and platform_machine == 'aarch64'",
            "bar >=0.5.0 ; python_version >= '3.9'",
        ]

        deps = wheel.Deps(
            "foo",
            requires_dist=requires_dist,
            platforms=wheel.Platform.from_string(["cp37_*", "cp310_*"]),
        )
        got = deps.build()

        self.assertEqual(["bar"], got.deps)
        self.assertEqual({}, got.deps_select)


class MinorVersionTest(unittest.TestCase):
    def test_host(self):
        host = wheel.host_interpreter_minor_version()
        self.assertIsNotNone(host)


class PlatformTest(unittest.TestCase):
    def test_can_get_host(self):
        host = wheel.Platform.host()
        self.assertIsNotNone(host)
        self.assertEqual(1, len(wheel.Platform.from_string("host")))
        self.assertEqual(host, wheel.Platform.from_string("host"))

    def test_can_get_linux_x86_64_without_py_version(self):
        got = wheel.Platform.from_string("linux_x86_64")
        want = wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_64)
        self.assertEqual(want, got[0])

    def test_can_get_specific_from_string(self):
        got = wheel.Platform.from_string("cp33_linux_x86_64")
        want = wheel.Platform(
            os=wheel.OS.linux, arch=wheel.Arch.x86_64, minor_version=3
        )
        self.assertEqual(want, got[0])

    def test_can_get_all_for_py_version(self):
        cp39 = wheel.Platform.all(minor_version=9)
        self.assertEqual(18, len(cp39), f"Got {cp39}")
        self.assertEqual(cp39, wheel.Platform.from_string("cp39_*"))

    def test_can_get_all_for_os(self):
        linuxes = wheel.Platform.all(wheel.OS.linux, minor_version=9)
        self.assertEqual(6, len(linuxes))
        self.assertEqual(linuxes, wheel.Platform.from_string("cp39_linux_*"))

    def test_can_get_all_for_os_for_host_python(self):
        linuxes = wheel.Platform.all(wheel.OS.linux)
        self.assertEqual(6, len(linuxes))
        self.assertEqual(linuxes, wheel.Platform.from_string("linux_*"))

    def test_specific_version_specializations(self):
        any_py33 = wheel.Platform(minor_version=3)

        # When
        all_specializations = list(any_py33.all_specializations())

        want = (
            [any_py33]
            + [
                wheel.Platform(arch=arch, minor_version=any_py33.minor_version)
                for arch in wheel.Arch
            ]
            + [
                wheel.Platform(os=os, minor_version=any_py33.minor_version)
                for os in wheel.OS
            ]
            + wheel.Platform.all(minor_version=any_py33.minor_version)
        )
        self.assertEqual(want, all_specializations)

    def test_aarch64_specializations(self):
        any_aarch64 = wheel.Platform(arch=wheel.Arch.aarch64)
        all_specializations = list(any_aarch64.all_specializations())
        want = [
            wheel.Platform(os=None, arch=wheel.Arch.aarch64),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.aarch64),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
            wheel.Platform(os=wheel.OS.windows, arch=wheel.Arch.aarch64),
        ]
        self.assertEqual(want, all_specializations)

    def test_linux_specializations(self):
        any_linux = wheel.Platform(os=wheel.OS.linux)
        all_specializations = list(any_linux.all_specializations())
        want = [
            wheel.Platform(os=wheel.OS.linux, arch=None),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_64),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_32),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.aarch64),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.ppc),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.s390x),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.arm),
        ]
        self.assertEqual(want, all_specializations)

    def test_osx_specializations(self):
        any_osx = wheel.Platform(os=wheel.OS.osx)
        all_specializations = list(any_osx.all_specializations())
        # NOTE @aignas 2024-01-14: even though in practice we would only have
        # Python on osx aarch64 and osx x86_64, we return all arch posibilities
        # to make the code simpler.
        want = [
            wheel.Platform(os=wheel.OS.osx, arch=None),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_32),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.ppc),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.s390x),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.arm),
        ]
        self.assertEqual(want, all_specializations)

    def test_platform_sort(self):
        platforms = [
            wheel.Platform(os=wheel.OS.linux, arch=None),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_64),
            wheel.Platform(os=wheel.OS.osx, arch=None),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
        ]
        shuffle(platforms)
        platforms.sort()
        want = [
            wheel.Platform(os=wheel.OS.linux, arch=None),
            wheel.Platform(os=wheel.OS.linux, arch=wheel.Arch.x86_64),
            wheel.Platform(os=wheel.OS.osx, arch=None),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.x86_64),
            wheel.Platform(os=wheel.OS.osx, arch=wheel.Arch.aarch64),
        ]

        self.assertEqual(want, platforms)

    def test_wheel_os_alias(self):
        self.assertEqual("osx", str(wheel.OS.osx))
        self.assertEqual(str(wheel.OS.darwin), str(wheel.OS.osx))

    def test_wheel_arch_alias(self):
        self.assertEqual("x86_64", str(wheel.Arch.x86_64))
        self.assertEqual(str(wheel.Arch.amd64), str(wheel.Arch.x86_64))

    def test_wheel_platform_alias(self):
        give = wheel.Platform(
            os=wheel.OS.darwin,
            arch=wheel.Arch.amd64,
        )
        alias = wheel.Platform(
            os=wheel.OS.osx,
            arch=wheel.Arch.x86_64,
        )

        self.assertEqual("osx_x86_64", str(give))
        self.assertEqual(str(alias), str(give))


if __name__ == "__main__":
    unittest.main()
