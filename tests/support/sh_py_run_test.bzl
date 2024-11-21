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

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//python:py_binary.bzl", "py_binary")
load("//python:py_test.bzl", "py_test")
load("//python/private:toolchain_types.bzl", "TARGET_TOOLCHAIN_TYPE")  # buildifier: disable=bzl-visibility
load("//tests/support:support.bzl", "VISIBLE_FOR_TESTING")

def _perform_transition_impl(input_settings, attr):
    settings = dict(input_settings)
    settings[VISIBLE_FOR_TESTING] = True
    settings["//command_line_option:build_python_zip"] = attr.build_python_zip
    if attr.bootstrap_impl:
        settings["//python/config_settings:bootstrap_impl"] = attr.bootstrap_impl
    if attr.extra_toolchains:
        settings["//command_line_option:extra_toolchains"] = attr.extra_toolchains
    if attr.python_version:
        settings["//python/config_settings:python_version"] = attr.python_version
    return settings

_perform_transition = transition(
    implementation = _perform_transition_impl,
    inputs = [
        "//python/config_settings:bootstrap_impl",
        "//command_line_option:extra_toolchains",
        "//python/config_settings:python_version",
    ],
    outputs = [
        "//command_line_option:build_python_zip",
        "//command_line_option:extra_toolchains",
        "//python/config_settings:bootstrap_impl",
        "//python/config_settings:python_version",
        VISIBLE_FOR_TESTING,
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
            # On windows, the other default outputs must also be included
            # in runfiles so the exe launcher can find the backing file.
            runfiles = ctx.runfiles(default_outputs).merge(
                default_info.default_runfiles,
            ),
        ),
        testing.TestEnvironment(
            environment = ctx.attr.env,
        ),
    ]

def _make_reconfig_rule(**kwargs):
    attrs = {
        "bootstrap_impl": attr.string(),
        "build_python_zip": attr.string(default = "auto"),
        "env": attr.string_dict(),
        "extra_toolchains": attr.string_list(
            doc = """
Value for the --extra_toolchains flag.

NOTE: You'll likely have to also specify //tests/support/cc_toolchains:all (or some CC toolchain)
to make the RBE presubmits happy, which disable auto-detection of a CC
toolchain.
""",
        ),
        "python_version": attr.string(),
        "target": attr.label(executable = True, cfg = "target"),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    }
    return rule(
        implementation = _py_reconfig_impl,
        attrs = attrs,
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
    reconfig_kwargs["bootstrap_impl"] = kwargs.pop("bootstrap_impl", None)
    reconfig_kwargs["extra_toolchains"] = kwargs.pop("extra_toolchains", None)
    reconfig_kwargs["python_version"] = kwargs.pop("python_version", None)
    reconfig_kwargs["env"] = kwargs.get("env")
    reconfig_kwargs["target_compatible_with"] = kwargs.get("target_compatible_with")

    inner_name = "_{}_inner".format(name)
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
    """Run a py_binary within a sh_test.

    Args:
        name: name of the sh_test and base name of inner targets.
        sh_src: .sh file to run as a test
        py_src: .py file for the py_binary
        **kwargs: additional kwargs passed onto py_binary and/or sh_test
    """
    bin_name = "_{}_bin".format(name)
    sh_test(
        name = name,
        srcs = [sh_src],
        data = [bin_name],
        deps = [
            "@bazel_tools//tools/bash/runfiles",
        ],
        env = {
            "BIN_RLOCATION": "$(rlocationpaths {})".format(bin_name),
        },
    )

    py_binary_kwargs = {
        key: kwargs.pop(key)
        for key in ("imports", "deps")
        if key in kwargs
    }

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
        **py_binary_kwargs
    )

def _current_build_settings_impl(ctx):
    info = ctx.actions.declare_file(ctx.label.name + ".json")
    toolchain = ctx.toolchains[TARGET_TOOLCHAIN_TYPE]
    runtime = toolchain.py3_runtime
    files = [info]
    ctx.actions.write(
        output = info,
        content = json.encode({
            "interpreter": {
                "short_path": runtime.interpreter.short_path if runtime.interpreter else None,
            },
            "interpreter_path": runtime.interpreter_path,
            "toolchain_label": str(getattr(toolchain, "toolchain_label", None)),
        }),
    )
    return [DefaultInfo(
        files = depset(files),
    )]

current_build_settings = rule(
    doc = """
Writes information about the current build config to JSON for testing.

This is so tests can verify information about the build config used for them.
""",
    implementation = _current_build_settings_impl,
    toolchains = [
        TARGET_TOOLCHAIN_TYPE,
    ],
)
