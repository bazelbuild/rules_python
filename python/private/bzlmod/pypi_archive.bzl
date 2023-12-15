# Copyright 2023 The Bazel Authors. All rights reserved.
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

"TODO"

load("//python:versions.bzl", "WINDOWS_NAME")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")
load("//python/private:patch_whl.bzl", "patch_whl")
load("//python/private:toolchains_repo.bzl", "get_host_os_arch")

def _impl(rctx):
    prefix, _, _ = rctx.attr.name.rpartition("_")
    prefix, _, _ = prefix.rpartition("_")

    metadata = struct(**json.decode(rctx.read(rctx.path(rctx.attr.metadata))))
    sha256 = rctx.attr.sha256
    url = None
    for file in metadata.files:
        if file["sha256"] == sha256:
            url = file["url"]
            break

    if url == None:
        fail("Could not find a file with sha256 '{}' within: {}".format(sha256, metadata))

    _, _, filename = url.rpartition("/")
    filename = filename.strip()
    result = rctx.download(url, output = filename, sha256 = sha256)
    if not result.success:
        fail(result)

    whl_path = rctx.path(filename)

    if rctx.attr.patches:
        patches = {}
        for patch_file, json_args in rctx.attr.patches.items():
            patch_dst = struct(**json.decode(json_args))
            if whl_path.basename in patch_dst.whls:
                patches[patch_file] = patch_dst.patch_strip

        # TODO @aignas 2023-12-14: re-parse the metadata to ensure that we have a
        # non-stale version of it
        # Something like: whl_path, metadata = patch_whl(
        whl_path = patch_whl(
            rctx,
            python_interpreter = _resolve_python_interpreter(rctx),
            whl_path = whl_path,
            patches = patches,
            quiet = rctx.attr.quiet,
            timeout = rctx.attr.timeout,
        )

    rctx.symlink(whl_path, "file")

    rctx.file(
        "BUILD.bazel",
        """\
filegroup(
    name="file",
    srcs=["{filename}"],
    visibility=["//visibility:public"],
)
""".format(filename = whl_path.basename),
    )

pypi_archive = repository_rule(
    attrs = {
        "metadata": attr.label(mandatory = True, allow_single_file = True),
        "patches": attr.label_keyed_string_dict(
            doc = """"a label-keyed-string dict that has
                json.encode(struct([whl_file], patch_strip]) as values. This
                is to maintain flexibility and correct bzlmod extension interface
                until we have a better way to define whl_library and move whl
                patching to a separate place. INTERNAL USE ONLY.""",
        ),
        "python_interpreter": attr.string(),
        "python_interpreter_target": attr.label(),
        "quiet": attr.bool(default = True),
        "sha256": attr.string(mandatory = False),
        "timeout": attr.int(default = 60),
    },
    doc = """A rule for bzlmod mulitple pip repository creation. PRIVATE USE ONLY.""",
    implementation = _impl,
)

def _get_python_interpreter_attr(rctx):
    """A helper function for getting the `python_interpreter` attribute or it's default

    Args:
        rctx (repository_ctx): Handle to the rule repository context.

    Returns:
        str: The attribute value or it's default
    """
    if rctx.attr.python_interpreter:
        return rctx.attr.python_interpreter

    if "win" in rctx.os.name:
        return "python.exe"
    else:
        return "python3"

def _resolve_python_interpreter(rctx):
    """Helper function to find the python interpreter from the common attributes

    Args:
        rctx: Handle to the rule repository context.
    Returns: Python interpreter path.
    """
    python_interpreter = _get_python_interpreter_attr(rctx)

    if rctx.attr.python_interpreter_target != None:
        python_interpreter = rctx.path(rctx.attr.python_interpreter_target)

        if BZLMOD_ENABLED:
            (os, _) = get_host_os_arch(rctx)

            # On Windows, the symlink doesn't work because Windows attempts to find
            # Python DLLs where the symlink is, not where the symlink points.
            if os == WINDOWS_NAME:
                python_interpreter = python_interpreter.realpath
    elif "/" not in python_interpreter:
        found_python_interpreter = rctx.which(python_interpreter)
        if not found_python_interpreter:
            fail("python interpreter `{}` not found in PATH".format(python_interpreter))
        python_interpreter = found_python_interpreter
    return python_interpreter
