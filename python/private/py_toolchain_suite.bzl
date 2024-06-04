# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Create the toolchain defs in a BUILD.bazel file."""

load("@bazel_skylib//lib:selects.bzl", "selects")
load(
    ":toolchain_types.bzl",
    "EXEC_TOOLS_TOOLCHAIN_TYPE",
    "PY_CC_TOOLCHAIN_TYPE",
    "TARGET_TOOLCHAIN_TYPE",
)

def py_toolchain_suite(*, prefix, user_repository_name, python_version, set_python_version_constraint, flag_values, **kwargs):
    """For internal use only.

    Args:
        prefix: Prefix for toolchain target names.
        user_repository_name: The name of the user repository.
        python_version: The full (X.Y.Z) version of the interpreter.
        set_python_version_constraint: True or False as a string.
        flag_values: Extra flag values to match for this toolchain.
        **kwargs: extra args passed to the `toolchain` calls.

    """

    # We have to use a String value here because bzlmod is passing in a
    # string as we cannot have list of bools in build rule attribues.
    # This if statement does not appear to work unless it is in the
    # toolchain file.
    if set_python_version_constraint in ["True", "False"]:
        major_minor, _, _ = python_version.rpartition(".")
        python_versions = [major_minor, python_version]
        if set_python_version_constraint == "False":
            python_versions.append("")

        match_any = []
        for i, v in enumerate(python_versions):
            name = "{prefix}_{python_version}_{i}".format(
                prefix = prefix,
                python_version = python_version,
                i = i,
            )
            match_any.append(name)
            native.config_setting(
                name = name,
                flag_values = flag_values | {
                    Label("@rules_python//python/config_settings:python_version"): v,
                },
                visibility = ["//visibility:private"],
            )

        name = "{prefix}_version_setting_{python_version}".format(
            prefix = prefix,
            python_version = python_version,
            visibility = ["//visibility:private"],
        )
        selects.config_setting_group(
            name = name,
            match_any = match_any,
            visibility = ["//visibility:private"],
        )
        target_settings = [name]
    else:
        fail(("Invalid set_python_version_constraint value: got {} {}, wanted " +
              "either the string 'True' or the string 'False'; " +
              "(did you convert bool to string?)").format(
            type(set_python_version_constraint),
            repr(set_python_version_constraint),
        ))

    native.toolchain(
        name = "{prefix}_toolchain".format(prefix = prefix),
        toolchain = "@{user_repository_name}//:python_runtimes".format(
            user_repository_name = user_repository_name,
        ),
        toolchain_type = TARGET_TOOLCHAIN_TYPE,
        target_settings = target_settings,
        **kwargs
    )

    native.toolchain(
        name = "{prefix}_py_cc_toolchain".format(prefix = prefix),
        toolchain = "@{user_repository_name}//:py_cc_toolchain".format(
            user_repository_name = user_repository_name,
        ),
        toolchain_type = PY_CC_TOOLCHAIN_TYPE,
        target_settings = target_settings,
        **kwargs
    )

    native.toolchain(
        name = "{prefix}_py_exec_tools_toolchain".format(prefix = prefix),
        toolchain = "@{user_repository_name}//:py_exec_tools_toolchain".format(
            user_repository_name = user_repository_name,
        ),
        toolchain_type = EXEC_TOOLS_TOOLCHAIN_TYPE,
        # The target settings capture the Python version
        target_settings = target_settings,
        exec_compatible_with = kwargs.get("target_compatible_with"),
    )

    # NOTE: When adding a new toolchain, for WORKSPACE builds to see the
    # toolchain, the name must be added to the native.register_toolchains()
    # call in python/repositories.bzl. Bzlmod doesn't need anything; it will
    # register `:all`.
