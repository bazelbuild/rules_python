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

_py_toolchain_type = Label("@bazel_tools//tools/python:toolchain_type")
_py_cc_toolchain_type = Label("//python/cc:toolchain_type")

def toolchain_defs(*, prefix, user_repository_name, python_version, set_python_version_constraint, **kwargs):
    """For internal use only.

    Args:
        prefix: Prefix for toolchain target names.
        user_repository_name: The name of the user repository.
        python_version: The full (X.Y.Z) version of the interpreter.
        set_python_version_constraint: True or False as a string.
        **kwargs: extra args passed to the `toolchain` calls.

    """

    # We have to use a String value here because bzlmod is passing in a
    # string as we cannot have list of bools in build rule attribues.
    # This if statement does not appear to work unless it is in the
    # toolchain file.
    if set_python_version_constraint == "True":
        major_minor, _, _ = python_version.rpartition(".")

        selects.config_setting_group(
            name = prefix + "_version_setting",
            match_any = [
                Label("//python/config_settings:is_python_%s" % v)
                for v in [
                    major_minor,
                    python_version,
                ]
            ],
            visibility = ["//visibility:private"],
        )
        target_settings = [prefix + "_version_setting"]
    elif set_python_version_constraint == "False":
        target_settings = []
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
        toolchain_type = _py_toolchain_type,
        target_settings = target_settings,
        **kwargs
    )

    native.toolchain(
        name = "{prefix}_py_cc_toolchain".format(prefix = prefix),
        toolchain = "@{user_repository_name}//:py_cc_toolchain".format(
            user_repository_name = user_repository_name,
        ),
        toolchain_type = _py_cc_toolchain_type,
        target_settings = target_settings,
        **kwargs
    )
