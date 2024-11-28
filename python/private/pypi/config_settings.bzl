# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
This module is used to construct the config settings for selecting which distribution is used in the pip hub repository.

Bazel's selects work by selecting the most-specialized configuration setting
that matches the target platform. We can leverage this fact to ensure that the
most specialized wheels are used by default with the users being able to
configure string_flag values to select the less specialized ones.

The list of specialization of the dists goes like follows:
* sdist
* py*-none-any.whl
* py*-abi3-any.whl
* py*-cpxy-any.whl
* cp*-none-any.whl
* cp*-abi3-any.whl
* cp*-cpxy-plat.whl
* py*-none-plat.whl
* py*-abi3-plat.whl
* py*-cpxy-plat.whl
* cp*-none-plat.whl
* cp*-abi3-plat.whl
* cp*-cpxy-plat.whl

Note, that here the specialization of musl vs manylinux wheels is the same in
order to ensure that the matching fails if the user requests for `musl` and we don't have it or vice versa.
"""

load("//python/private:flags.bzl", "LibcFlag")
load(":flags.bzl", "INTERNAL_FLAGS", "UniversalWhlFlag")

FLAGS = struct(
    **{
        f: str(Label("//python/config_settings:" + f))
        for f in [
            "python_version",
            "pip_whl_glibc_version",
            "pip_whl_muslc_version",
            "pip_whl_osx_arch",
            "pip_whl_osx_version",
            "py_linux_libc",
            "is_pip_whl_no",
            "is_pip_whl_only",
            "is_pip_whl_auto",
        ]
    }
)

# Here we create extra string flags that are just to work with the select
# selecting the most specialized match. We don't allow the user to change
# them.
_flags = struct(
    **{
        f: str(Label("//python/config_settings:_internal_pip_" + f))
        for f in INTERNAL_FLAGS
    }
)

def config_settings(
        *,
        python_versions = [],
        glibc_versions = [],
        muslc_versions = [],
        osx_versions = [],
        target_platforms = [],
        name = None,
        visibility = None,
        native = native):
    """Generate all of the pip config settings.

    Args:
        name (str): Currently unused.
        python_versions (list[str]): The list of python versions to configure
            config settings for.
        glibc_versions (list[str]): The list of glibc version of the wheels to
            configure config settings for.
        muslc_versions (list[str]): The list of musl version of the wheels to
            configure config settings for.
        osx_versions (list[str]): The list of OSX OS versions to configure
            config settings for.
        target_platforms (list[str]): The list of "{os}_{cpu}" for deriving
            constraint values for each condition.
        visibility (list[str], optional): The visibility to be passed to the
            exposed labels. All other labels will be private.
        native (struct): The struct containing alias and config_setting rules
            to use for creating the objects. Can be overridden for unit tests
            reasons.
    """

    glibc_versions = [""] + glibc_versions
    muslc_versions = [""] + muslc_versions
    osx_versions = [""] + osx_versions
    target_platforms = [("", "")] + [
        t.split("_", 1)
        for t in target_platforms
    ]

    for python_version in [""] + python_versions:
        is_python = "is_python_{}".format(python_version or "version_unset")

        # The aliases defined in @rules_python//python/config_settings may not
        # have config settings for the versions we need, so define our own
        # config settings instead.
        native.config_setting(
            name = is_python,
            flag_values = {
                Label("//python/config_settings:python_version_major_minor"): python_version,
            },
            visibility = visibility,
        )

        for os, cpu in target_platforms:
            constraint_values = []
            suffix = ""
            if os:
                constraint_values.append("@platforms//os:" + os)
                suffix += "_" + os
            if cpu:
                constraint_values.append("@platforms//cpu:" + cpu)
                suffix += "_" + cpu

            _dist_config_settings(
                suffix = suffix,
                plat_flag_values = _plat_flag_values(
                    os = os,
                    cpu = cpu,
                    osx_versions = osx_versions,
                    glibc_versions = glibc_versions,
                    muslc_versions = muslc_versions,
                ),
                constraint_values = constraint_values,
                python_version = python_version,
                is_python = is_python,
                visibility = visibility,
                native = native,
            )

def _dist_config_settings(*, suffix, plat_flag_values, **kwargs):
    if kwargs.get("constraint_values"):
        # Add python version + platform config settings
        _dist_config_setting(
            name = suffix.strip("_"),
            **kwargs
        )

    flag_values = {_flags.dist: ""}

    # First create an sdist, we will be building upon the flag values, which
    # will ensure that each sdist config setting is the least specialized of
    # all. However, we need at least one flag value to cover the case where we
    # have `sdist` for any platform, hence we have a non-empty `flag_values`
    # here.
    _dist_config_setting(
        name = "sdist{}".format(suffix),
        flag_values = flag_values,
        is_pip_whl = FLAGS.is_pip_whl_no,
        **kwargs
    )

    for name, f in [
        ("py_none", _flags.whl_py2_py3),
        ("py3_none", _flags.whl_py3),
        ("py3_abi3", _flags.whl_py3_abi3),
        ("cp3x_none", _flags.whl_pycp3x),
        ("cp3x_abi3", _flags.whl_pycp3x_abi3),
        ("cp3x_cp", _flags.whl_pycp3x_abicp),
    ]:
        if f in flag_values:
            # This should never happen as all of the different whls should have
            # unique flag values.
            fail("BUG: the flag {} is attempted to be added twice to the list".format(f))
        else:
            flag_values[f] = ""

        _dist_config_setting(
            name = "{}_any{}".format(name, suffix),
            flag_values = flag_values,
            is_pip_whl = FLAGS.is_pip_whl_only,
            **kwargs
        )

    generic_flag_values = flag_values

    for (suffix, flag_values) in plat_flag_values:
        flag_values = flag_values | generic_flag_values

        for name, f in [
            ("py_none", _flags.whl_plat),
            ("py3_none", _flags.whl_plat_py3),
            ("py3_abi3", _flags.whl_plat_py3_abi3),
            ("cp3x_none", _flags.whl_plat_pycp3x),
            ("cp3x_abi3", _flags.whl_plat_pycp3x_abi3),
            ("cp3x_cp", _flags.whl_plat_pycp3x_abicp),
        ]:
            if f in flag_values:
                # This should never happen as all of the different whls should have
                # unique flag values.
                fail("BUG: the flag {} is attempted to be added twice to the list".format(f))
            else:
                flag_values[f] = ""

            _dist_config_setting(
                name = "{}_{}".format(name, suffix),
                flag_values = flag_values,
                is_pip_whl = FLAGS.is_pip_whl_only,
                **kwargs
            )

def _to_version_string(version, sep = "."):
    if not version:
        return ""

    return "{}{}{}".format(version[0], sep, version[1])

def _plat_flag_values(os, cpu, osx_versions, glibc_versions, muslc_versions):
    ret = []
    if os == "":
        return []
    elif os == "windows":
        ret.append(("{}_{}".format(os, cpu), {}))
    elif os == "osx":
        for cpu_, arch in {
            cpu: UniversalWhlFlag.ARCH,
            cpu + "_universal2": UniversalWhlFlag.UNIVERSAL,
        }.items():
            for osx_version in osx_versions:
                flags = {
                    FLAGS.pip_whl_osx_version: _to_version_string(osx_version),
                }
                if arch == UniversalWhlFlag.ARCH:
                    flags[FLAGS.pip_whl_osx_arch] = arch

                if not osx_version:
                    suffix = "{}_{}".format(os, cpu_)
                else:
                    suffix = "{}_{}_{}".format(os, _to_version_string(osx_version, "_"), cpu_)

                ret.append((suffix, flags))

    elif os == "linux":
        for os_prefix, linux_libc in {
            os: LibcFlag.GLIBC,
            "many" + os: LibcFlag.GLIBC,
            "musl" + os: LibcFlag.MUSL,
        }.items():
            if linux_libc == LibcFlag.GLIBC:
                libc_versions = glibc_versions
                libc_flag = FLAGS.pip_whl_glibc_version
            elif linux_libc == LibcFlag.MUSL:
                libc_versions = muslc_versions
                libc_flag = FLAGS.pip_whl_muslc_version
            else:
                fail("Unsupported libc type: {}".format(linux_libc))

            for libc_version in libc_versions:
                if libc_version and os_prefix == os:
                    continue
                elif libc_version:
                    suffix = "{}_{}_{}".format(os_prefix, _to_version_string(libc_version, "_"), cpu)
                else:
                    suffix = "{}_{}".format(os_prefix, cpu)

                ret.append((
                    suffix,
                    {
                        FLAGS.py_linux_libc: linux_libc,
                        libc_flag: _to_version_string(libc_version),
                    },
                ))
    else:
        fail("Unsupported os: {}".format(os))

    return ret

def _dist_config_setting(*, name, is_python, python_version, is_pip_whl = None, native = native, **kwargs):
    """A macro to create a target that matches is_pip_whl_auto and one more value.

    Args:
        name: The name of the public target.
        is_pip_whl: The config setting to match in addition to
            `is_pip_whl_auto` when evaluating the config setting.
        is_python: The python version config_setting to match.
        python_version: The python version name.
        native (struct): The struct containing alias and config_setting rules
            to use for creating the objects. Can be overridden for unit tests
            reasons.
        **kwargs: The kwargs passed to the config_setting rule. Visibility of
            the main alias target is also taken from the kwargs.
    """
    _name = "_is_" + name

    visibility = kwargs.get("visibility")
    native.alias(
        name = "is_cp{}_{}".format(python_version, name) if python_version else "is_{}".format(name),
        actual = select({
            # First match by the python version
            is_python: _name,
            "//conditions:default": is_python,
        }),
        visibility = visibility,
    )

    if python_version:
        # Reuse the config_setting targets that we use with the default
        # `python_version` setting.
        return

    if not is_pip_whl:
        native.config_setting(name = _name, **kwargs)
        return

    config_setting_name = _name + "_setting"
    native.config_setting(name = config_setting_name, **kwargs)

    # Next match by the `pip_whl` flag value and then match by the flags that
    # are intrinsic to the distribution.
    native.alias(
        name = _name,
        actual = select({
            "//conditions:default": FLAGS.is_pip_whl_auto,
            FLAGS.is_pip_whl_auto: config_setting_name,
            is_pip_whl: config_setting_name,
        }),
        visibility = visibility,
    )
