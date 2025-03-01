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

"""A simple macro to lock the requirements.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//python:py_binary.bzl", "py_binary")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")  # buildifier: disable=bzl-visibility

visibility(["//..."])

_REQUIREMENTS_TARGET_COMPATIBLE_WITH = [] if BZLMOD_ENABLED else ["@platforms//:incompatible"]

def _impl(ctx):
    args = ctx.actions.args()
    if ctx.files.src_outs:
        # This means that the output file already exists and it should be used
        # to create a new file. This will be taken care by the locker tool.
        args.add_all([
            "--src-out",
            ctx.files.src_outs[0].path,
        ])

    args.add_all([
        "pip",
        "compile",
        "--custom-compile-command=bazel run {}".format(ctx.attr.update_target),
        "--generate-hashes",
        "--emit-index-url",
        "--no-strip-extras",
        "--no-python-downloads",
    ])

    cache_dir = ctx.actions.declare_directory(".uv_cache_{}".format(ctx.label.name))
    args.add_all(["--cache-dir", cache_dir], expand_directories = False)

    args.add_all(ctx.attr.args)
    srcs = ctx.files.srcs

    args.add_all(srcs)
    if ctx.attr.upgrade:
        args.add("--upgrade")

    if ctx.attr.universal:
        args.add("--universal")

    args.add("--output-file", ctx.outputs.out)
    ctx.actions.run(
        executable = ctx.executable._locker,
        inputs = srcs,
        outputs = [
            ctx.outputs.out,
            cache_dir,
        ],
        arguments = [args],
        tools = [
            ctx.executable._locker,
        ],
        progress_message = "Locking requirements using uv",
        env = ctx.attr.env,
    )

    return [
        DefaultInfo(files = depset([ctx.outputs.out])),
    ]

_lock = rule(
    implementation = _impl,
    doc = """\
""",
    attrs = {
        "args": attr.string_list(),
        "env": attr.string_dict(),
        "out": attr.output(mandatory = True),
        "src_outs": attr.label_list(mandatory = True, allow_files = True),
        "srcs": attr.label_list(mandatory = True, allow_files = True),
        "universal": attr.bool(default = True),
        "update_target": attr.string(mandatory = True),
        "upgrade": attr.bool(default = False),
        "_locker": attr.label(
            default = "//python/uv/private:locker",
            executable = True,
            cfg = "target",
        ),
    },
)

def lock(*, name, srcs, out, upgrade = False, universal = True, args = [], **kwargs):
    """Pin the requirements based on the src files.

    Differences with the current {obj}`compile_pip_requirements` rule:
    - This is implemented in shell and uv.
    - This does not error out if the output file does not exist yet.
    - Supports transitions out of the box.

    Args:
        name: The name of the target to run for updating the requirements.
        srcs: The srcs to use as inputs.
        out: The output file.
        upgrade: Tell `uv` to always upgrade the dependencies instead of
            keeping them as they are.
        universal: Tell `uv` to generate a universal lock file.
        args: Extra args to pass to `uv`.
        **kwargs: Extra kwargs passed to the {obj}`py_binary` rule.
    """
    pkg = native.package_name()
    update_target = name + ".update"
    _lock(
        name = name,
        srcs = srcs,
        # Check if the output file already exists, if yes, first copy it to the
        # output file location in order to make `uv` not change the requirements if
        # we are just running the command.
        src_outs = native.glob([out]),
        update_target = "@//{}:{}".format(pkg, update_target),
        out = out + ".new",
        tags = [
            "local",
            "manual",
            "no-cache",
        ],
        universal = universal,
        upgrade = upgrade,
        args = args,
        target_compatible_with = _REQUIREMENTS_TARGET_COMPATIBLE_WITH,
    )

    # Write a script that can be used for updating the in-tree version of the
    # requirements file
    write_file(
        name = name + ".update_gen",
        out = update_target + ".py",
        content = [
            "from os import environ",
            "from pathlib import Path",
            "from sys import stderr",
            "",
            'src = Path(environ["REQUIREMENTS_FILE"])',
            'assert src.exists(), f"the {src} file does not exist"',
            'dst = Path(environ["BUILD_WORKSPACE_DIRECTORY"]) / "{}" / "{}"'.format(pkg, out),
            'print(f"Writing requirements contents\\n  from {src.absolute()}\\n  to {dst.absolute()}", file=stderr)',
            "dst.write_text(src.read_text())",
            'print("Success!", file=stderr)',
        ],
    )

    py_binary(
        name = update_target,
        srcs = [update_target + ".py"],
        main = update_target + ".py",
        data = [name],
        env = {
            "REQUIREMENTS_FILE": "$(rootpath {})".format(name),
        },
        tags = ["manual"],
        **kwargs
    )
