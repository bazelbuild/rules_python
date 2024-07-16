# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Run a py_binary with altered config settings in an sh_test.

This facilitates verify running binaries with different configuration settings
without the overhead of a bazel-in-bazel integration test.
"""

load("//python:py_binary.bzl", "py_binary")
load("//python:py_test.bzl", "py_test")

def _perform_transition_impl(input_settings, attr):
    settings = dict(input_settings)
    settings["//command_line_option:build_python_zip"] = attr.build_python_zip
    if attr.bootstrap_impl:
        settings["//python/config_settings:bootstrap_impl"] = attr.bootstrap_impl
    return settings

_perform_transition = transition(
    implementation = _perform_transition_impl,
    inputs = [
        "//python/config_settings:bootstrap_impl",
    ],
    outputs = [
        "//command_line_option:build_python_zip",
        "//python/config_settings:bootstrap_impl",
    ],
)

def _py_reconfig_impl(ctx):
    default_info = ctx.attr.target[DefaultInfo]
    exe_ext = default_info.files_to_run.executable.extension
    if exe_ext:
        exe_ext = "." + exe_ext
    exe_name = ctx.label.name + exe_ext

    executable = ctx.actions.declare_file(exe_name)
    ctx.actions.symlink(output = executable, target_file = default_info.files_to_run.executable)

    default_outputs = [executable]

    # todo: could probably check target.owner vs src.owner to check if it should
    # be symlinked or included as-is
    # For simplicity of implementation, we're assuming the target being run is
    # py_binary-like. In order for Windows to work, we need to make sure the
    # file that the .exe launcher runs (the .zip or underlying non-exe
    # executable) is a sibling of the .exe file with the same base name.
    for src in default_info.files.to_list():
        if src.extension in ("", "zip"):
            ext = ("." if src.extension else "") + src.extension
            output = ctx.actions.declare_file(ctx.label.name + ext)
            ctx.actions.symlink(output = output, target_file = src)
            default_outputs.append(output)

    return [
        DefaultInfo(
            executable = executable,
            files = depset(default_outputs),
            runfiles = default_info.default_runfiles,
        ),
        testing.TestEnvironment(
            environment = ctx.attr.env,
        ),
    ]

def _make_reconfig_rule(**kwargs):
    return rule(
        implementation = _py_reconfig_impl,
        attrs = {
            "bootstrap_impl": attr.string(),
            "build_python_zip": attr.string(default = "auto"),
            "env": attr.string_dict(),
            "target": attr.label(executable = True, cfg = "target"),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
        cfg = _perform_transition,
        **kwargs
    )

_py_reconfig_binary = _make_reconfig_rule(executable = True)

_py_reconfig_test = _make_reconfig_rule(test = True)

def py_reconfig_test(*, name, **kwargs):
    """Create a py_test with customized build settings for testing.

    Args:
        name: str, name of teset target.
        **kwargs: kwargs to pass along to _py_reconfig_test and py_test.
    """
    reconfig_kwargs = {}
    reconfig_kwargs["bootstrap_impl"] = kwargs.pop("bootstrap_impl")
    reconfig_kwargs["env"] = kwargs.get("env")
    inner_name = "_{}_inner" + name
    _py_reconfig_test(
        name = name,
        target = inner_name,
        **reconfig_kwargs
    )
    py_test(
        name = inner_name,
        tags = ["manual"],
        **kwargs
    )

def sh_py_run_test(*, name, sh_src, py_src, **kwargs):
    bin_name = "_{}_bin".format(name)
    native.sh_test(
        name = name,
        srcs = [sh_src],
        data = [bin_name],
        deps = [
            "@bazel_tools//tools/bash/runfiles",
        ],
        env = {
            "BIN_RLOCATION": "$(rlocationpath {})".format(bin_name),
        },
    )

    _py_reconfig_binary(
        name = bin_name,
        tags = ["manual"],
        target = "_{}_plain_bin".format(name),
        **kwargs
    )

    py_binary(
        name = "_{}_plain_bin".format(name),
        srcs = [py_src],
        main = py_src,
        tags = ["manual"],
    )
