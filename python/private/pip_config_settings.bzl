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

load(
    ":pip_flags.bzl",
    "INTERNAL_FLAGS",
    "UniversalWhlFlag",
    "WhlLibcFlag",
)

FLAGS = struct(
    **{
        f: str(Label("//python/config_settings:" + f))
        for f in [
            "python_version",
            "pip_whl",
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

def pip_config_settings(
        *,
        python_versions = [],
        glibc_versions = [],
        muslc_versions = [],
        osx_versions = [],
        target_platforms = [],
        name = None,
        visibility = None,
        alias_rule = None,
        config_setting_rule = None):
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
        alias_rule (rule): The alias rule to use for creating the
            objects. Can be overridden for unit tests reasons.
        config_setting_rule (rule): The config setting rule to use for creating the
            objects. Can be overridden for unit tests reasons.
    """

    glibc_versions = [""] + glibc_versions
    muslc_versions = [""] + muslc_versions
    osx_versions = [""] + osx_versions
    target_platforms = [("", "")] + [
        t.split("_", 1)
        for t in target_platforms
    ]

    alias_rule = alias_rule or native.alias

    for version in ["default"] + python_versions:
        is_python = "is_python_{}".format(version)
        alias_rule(
            name = is_python,
            actual = Label("//python/config_settings:" + is_python),
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

        _sdist_config_setting(
            name = "sdist" + suffix,
            constraint_values = constraint_values,
            visibility = visibility,
            config_setting_rule = config_setting_rule,
        )
        for python_version in python_versions:
            _sdist_config_setting(
                name = "cp{}_sdist{}".format(python_version, suffix),
                python_version = python_version,
                constraint_values = constraint_values,
                visibility = visibility,
                config_setting_rule = config_setting_rule,
            )

        for python_version in [""] + python_versions:
            _whl_config_settings(
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
                visibility = visibility,
                config_setting_rule = config_setting_rule,
            )

def _whl_config_settings(*, suffix, plat_flag_values, **kwargs):
    # With the following three we cover different per-version wheels
    python_version = kwargs.get("python_version")
    py = "cp{}_py".format(python_version) if python_version else "py"
    pycp = "cp{}_cp3x".format(python_version) if python_version else "cp3x"

    flag_values = {}

    for n, f in {
        "{}_none_any{}".format(py, suffix): _flags.whl_py2_py3,
        "{}3_none_any{}".format(py, suffix): _flags.whl_py3,
        "{}3_abi3_any{}".format(py, suffix): _flags.whl_py3_abi3,
        "{}_none_any{}".format(pycp, suffix): _flags.whl_pycp3x,
        "{}_abi3_any{}".format(pycp, suffix): _flags.whl_pycp3x_abi3,
        "{}_cp_any{}".format(pycp, suffix): _flags.whl_pycp3x_abicp,
    }.items():
        if f in flag_values:
            # This should never happen as all of the different whls should have
            # unique flag values.
            fail("BUG: the flag {} is attempted to be added twice to the list".format(f))
        else:
            flag_values[f] = ""

        _whl_config_setting(
            name = n,
            flag_values = flag_values,
            **kwargs
        )

    generic_flag_values = flag_values

    for (suffix, flag_values) in plat_flag_values:
        flag_values = flag_values | generic_flag_values

        for n, f in {
            "{}_none_{}".format(py, suffix): _flags.whl_plat,
            "{}3_none_{}".format(py, suffix): _flags.whl_plat_py3,
            "{}3_abi3_{}".format(py, suffix): _flags.whl_plat_py3_abi3,
            "{}_none_{}".format(pycp, suffix): _flags.whl_plat_pycp3x,
            "{}_abi3_{}".format(pycp, suffix): _flags.whl_plat_pycp3x_abi3,
            "{}_cp_{}".format(pycp, suffix): _flags.whl_plat_pycp3x_abicp,
        }.items():
            if f in flag_values:
                # This should never happen as all of the different whls should have
                # unique flag values.
                fail("BUG: the flag {} is attempted to be added twice to the list".format(f))
            else:
                flag_values[f] = ""

            _whl_config_setting(
                name = n,
                flag_values = flag_values,
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
            os: WhlLibcFlag.GLIBC,
            "many" + os: WhlLibcFlag.GLIBC,
            "musl" + os: WhlLibcFlag.MUSL,
        }.items():
            if linux_libc == WhlLibcFlag.GLIBC:
                libc_versions = glibc_versions
                libc_flag = FLAGS.pip_whl_glibc_version
            elif linux_libc == WhlLibcFlag.MUSL:
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

def _whl_config_setting(*, name, flag_values, config_setting_rule = None, **kwargs):
    config_setting_rule = config_setting_rule or _config_setting_or
    config_setting_rule(
        name = "is_" + name,
        flag_values = flag_values,
        use_whl_flag = FLAGS.is_pip_whl_only,
        **kwargs
    )

def _sdist_config_setting(*, name, config_setting_rule = None, **kwargs):
    config_setting_rule = config_setting_rule or _config_setting_or
    config_setting_rule(
        name = "is_" + name,
        use_whl_flag = FLAGS.is_pip_whl_no,
        **kwargs
    )

def _config_setting_or(*, name, use_whl_flag, python_version = "", **kwargs):
    if python_version:
        _name = name.replace("is_cp{}".format(python_version), "_is")
    else:
        _name = "_" + name

    is_python = ":is_python_" + (python_version or "default")
    visibility = kwargs.get("visibility")
    native.alias(
        name = name,
        actual = select({
            is_python: _name,
            "//conditions:default": is_python,
        }),
        visibility = visibility,
    )

    if python_version:
        # Reuse the config_setting targets that we use with the default
        # `python_version` setting.
        return

    match_name = "_{}_1".format(name)
    native.config_setting(
        name = match_name,
        flag_values = {
            _flags.dist: "",
        } | kwargs.pop("flag_values", {}),
        **kwargs
    )
    native.alias(
        name = _name,
        actual = select({
            FLAGS.is_pip_whl_auto: match_name,
            use_whl_flag: match_name,
            "//conditions:default": use_whl_flag,
        }),
        visibility = visibility,
    )
