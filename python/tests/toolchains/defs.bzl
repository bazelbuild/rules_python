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

"""This module contains the definition for the toolchains testing rules.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//python:versions.bzl", "PLATFORMS", "TOOL_VERSIONS")

_WINDOWS_RUNNER_TEMPLATE = """\
@ECHO OFF
set PATHEXT=.COM;.EXE;.BAT
powershell.exe -c "& ./{interpreter_path} {run_acceptance_test_py}"
"""

def _acceptance_test_impl(ctx):
    workspace = ctx.actions.declare_file("/".join([ctx.attr.python_version, "WORKSPACE"]))
    ctx.actions.expand_template(
        template = ctx.file._workspace_tmpl,
        output = workspace,
        substitutions = {"%python_version%": ctx.attr.python_version},
    )

    build_bazel = ctx.actions.declare_file("/".join([ctx.attr.python_version, "BUILD.bazel"]))
    ctx.actions.expand_template(
        template = ctx.file._build_bazel_tmpl,
        output = build_bazel,
        substitutions = {"%python_version%": ctx.attr.python_version},
    )

    symlinks = [
        _symlink(ctx, file)
        for file in [
            ctx.file._native_extension_test,
            ctx.file._python_version_test,
            # With the current approach in the run_acceptance_test.sh, we use this
            # symlink to find the absolute path to the rules_python to be passed to the
            # --override_repository rules_python=<rules_python_path>.
            ctx.file._requirements_txt,
        ]
    ]

    run_acceptance_test_py = ctx.actions.declare_file("/".join([ctx.attr.python_version, "run_acceptance_test.py"]))
    ctx.actions.expand_template(
        template = ctx.file._run_acceptance_test_tmpl,
        output = run_acceptance_test_py,
        substitutions = {
            "%is_windows%": str(ctx.attr.is_windows),
            "%python_version%": ctx.attr.python_version,
            "%test_location%": "/".join([ctx.attr.test_location, ctx.attr.python_version]),
        },
    )

    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    py3_runtime = toolchain.py3_runtime
    interpreter_path = py3_runtime.interpreter_path
    if not interpreter_path:
        interpreter_path = py3_runtime.interpreter.short_path

    if ctx.attr.is_windows:
        executable = ctx.actions.declare_file("run_test_{}.bat".format(ctx.attr.python_version))
        ctx.actions.write(
            output = executable,
            content = _WINDOWS_RUNNER_TEMPLATE.format(
                interpreter_path = interpreter_path.replace("../", "external/"),
                run_acceptance_test_py = run_acceptance_test_py.short_path,
            ),
            is_executable = True,
        )
    else:
        executable = ctx.actions.declare_file("run_test_{}.sh".format(ctx.attr.python_version))
        ctx.actions.write(
            output = executable,
            content = "exec '{interpreter_path}' '{run_acceptance_test_py}'".format(
                interpreter_path = interpreter_path,
                run_acceptance_test_py = run_acceptance_test_py.short_path,
            ),
            is_executable = True,
        )

    files = [
        build_bazel,
        executable,
        run_acceptance_test_py,
        workspace,
    ] + symlinks
    return [DefaultInfo(
        executable = executable,
        files = depset(
            direct = files,
            transitive = [py3_runtime.files],
        ),
        runfiles = ctx.runfiles(
            files = files,
            transitive_files = py3_runtime.files,
        ),
    )]

def _symlink(ctx, file):
    filename = paths.basename(file.short_path)
    symlink = ctx.actions.declare_file("/".join([ctx.attr.python_version, filename]))
    ctx.actions.symlink(
        target_file = file,
        output = symlink,
    )
    return symlink

_acceptance_test = rule(
    implementation = _acceptance_test_impl,
    doc = "A rule for the toolchain acceptance tests.",
    attrs = {
        "is_windows": attr.bool(
            doc = "(Provided by the macro) Whether this is running under Windows or not.",
            mandatory = True,
        ),
        "python_version": attr.string(
            doc = "The Python version to be used when requesting the toolchain.",
            mandatory = True,
        ),
        "test_location": attr.string(
            doc = "(Provided by the macro) The value of native.package_name().",
            mandatory = True,
        ),
        "_build_bazel_tmpl": attr.label(
            doc = "The BUILD.bazel template.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains/workspace_template:BUILD.bazel.tmpl"),
        ),
        "_native_extension_test": attr.label(
            doc = "The native_extension_test.py used to test if the interpreter can deal with native extensions.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains/workspace_template:native_extension_test.py"),
        ),
        "_python_version_test": attr.label(
            doc = "The python_version_test.py used to test the Python version.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains/workspace_template:python_version_test.py"),
        ),
        "_requirements_txt": attr.label(
            doc = "The requirements.txt file.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains/workspace_template:requirements.txt"),
        ),
        "_run_acceptance_test_tmpl": attr.label(
            doc = "The run_acceptance_test.py template.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains:run_acceptance_test.py.tmpl"),
        ),
        "_workspace_tmpl": attr.label(
            doc = "The WORKSPACE template.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains/workspace_template:WORKSPACE.tmpl"),
        ),
    },
    test = True,
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
)

def acceptance_test(python_version, **kwargs):
    _acceptance_test(
        is_windows = select({
            "@bazel_tools//src/conditions:host_windows": True,
            "//conditions:default": False,
        }),
        python_version = python_version,
        test_location = native.package_name(),
        **kwargs
    )

# buildifier: disable=unnamed-macro
def acceptance_tests():
    """Creates a matrix of acceptance_test targets for all the toolchains.
    """
    for python_version in TOOL_VERSIONS.keys():
        for platform, meta in PLATFORMS.items():
            if platform not in TOOL_VERSIONS[python_version]["sha256"]:
                continue
            acceptance_test(
                name = "python_{python_version}_{platform}_test".format(
                    python_version = python_version.replace(".", "_"),
                    platform = platform,
                ),
                python_version = python_version,
                target_compatible_with = meta.compatible_with,
            )
