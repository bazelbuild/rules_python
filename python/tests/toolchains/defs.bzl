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

load("//python:versions.bzl", "PLATFORMS", "TOOL_VERSIONS")

_WINDOWS_RUNNER_TEMPLATE = """\
@ECHO OFF
set PATHEXT=.COM;.EXE;.BAT
powershell.exe -c "& ./{interpreter_path} {run_acceptance_test_py}"
"""

def _acceptance_test_impl(ctx):
    stub_shebang = "hermetic-stub-shebang" if ctx.attr.hermetic_stub_shebang else "default-stub-shebang"
    workspace_dir = "/".join([ctx.attr.python_version, stub_shebang])
    workspace = ctx.actions.declare_file("/".join([workspace_dir, "WORKSPACE"]))
    ctx.actions.expand_template(
        template = ctx.file._workspace_tmpl,
        output = workspace,
        substitutions = {
            "%python_version%": ctx.attr.python_version,
            "%hermetic_stub_shebang%": repr(ctx.attr.hermetic_stub_shebang),
        },
    )

    build_bazel = ctx.actions.declare_file("/".join([workspace_dir, "BUILD.bazel"]))
    ctx.actions.expand_template(
        template = ctx.file._build_bazel_tmpl,
        output = build_bazel,
        substitutions = {"%python_version%": ctx.attr.python_version},
    )

    python_version_test = ctx.actions.declare_file("/".join([workspace_dir, "python_version_test.py"]))

    # With the current approach in the run_acceptance_test.sh, we use this
    # symlink to find the absolute path to the rules_python to be passed to the
    # --override_repository rules_python=<rules_python_path>.
    ctx.actions.symlink(
        target_file = ctx.file._python_version_test,
        output = python_version_test,
    )

    run_acceptance_test_py = ctx.actions.declare_file("/".join([workspace_dir, "run_acceptance_test.py"]))
    ctx.actions.expand_template(
        template = ctx.file._run_acceptance_test_tmpl,
        output = run_acceptance_test_py,
        substitutions = {
            "%is_windows%": str(ctx.attr.is_windows),
            "%python_version%": ctx.attr.python_version,
            "%test_location%": "/".join([ctx.attr.test_location, workspace_dir]),
        },
    )

    toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]
    py3_runtime = toolchain.py3_runtime
    interpreter_path = py3_runtime.interpreter_path
    if not interpreter_path:
        interpreter_path = py3_runtime.interpreter.short_path

    if ctx.attr.is_windows:
        executable = ctx.actions.declare_file("run_test_{}_{}.bat".format(ctx.attr.python_version, stub_shebang))
        ctx.actions.write(
            output = executable,
            content = _WINDOWS_RUNNER_TEMPLATE.format(
                interpreter_path = interpreter_path.replace("../", "external/"),
                run_acceptance_test_py = run_acceptance_test_py.short_path,
            ),
            is_executable = True,
        )
    else:
        executable = ctx.actions.declare_file("run_test_{}_{}.sh".format(ctx.attr.python_version, stub_shebang))
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
        python_version_test,
        run_acceptance_test_py,
        workspace,
    ]
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

_acceptance_test = rule(
    implementation = _acceptance_test_impl,
    doc = "A rule for the toolchain acceptance tests.",
    attrs = {
        "hermetic_stub_shebang": attr.bool(
            doc = "Whether to enable Python toolchain stub shebang for executable wrapper.",
            mandatory = True,
        ),
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
        "_python_version_test": attr.label(
            doc = "The python_version_test.py used to test the Python version.",
            allow_single_file = True,
            default = Label("//python/tests/toolchains/workspace_template:python_version_test.py"),
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

def acceptance_test(python_version, hermetic_stub_shebang = False, **kwargs):
    _acceptance_test(
        hermetic_stub_shebang = hermetic_stub_shebang,
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
            for hermetic_stub_shebang in [False, True]:
                stub_shebang = "hermetic-stub-shebang" if hermetic_stub_shebang else "default-stub-shebang"
                acceptance_test(
                    name = "python_{python_version}_{platform}_{stub_shebang}_test".format(
                        python_version = python_version.replace(".", "_"),
                        platform = platform,
                        stub_shebang = stub_shebang,
                    ),
                    python_version = python_version,
                    hermetic_stub_shebang = hermetic_stub_shebang,
                    target_compatible_with = meta.compatible_with,
                )
