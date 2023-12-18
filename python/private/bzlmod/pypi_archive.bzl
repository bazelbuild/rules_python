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
load("//python/private:auth.bzl", "get_auth")
load("//python/private:bzlmod_enabled.bzl", "BZLMOD_ENABLED")
load("//python/private:patch_whl.bzl", "patch_whl")
load("//python/private:toolchains_repo.bzl", "get_host_os_arch")

_HTTP_FILE_DOC = """See documentation for the attribute with the same name
in [http_file docs](https://bazel.build/rules/lib/repo/http#http_file document)."""

def _impl(rctx):
    prefix, _, _ = rctx.attr.name.rpartition("_")
    prefix, _, _ = prefix.rpartition("_")

    _, _, filename = rctx.attr.urls[0].rpartition("/")
    filename = filename.strip()

    urls = rctx.attr.urls
    auth = get_auth(rctx, urls)

    result = rctx.download(
        url = urls,
        output = filename,
        sha256 = rctx.attr.sha256,
        auth = auth,
        canonical_id = rctx.attr.canonical_id,
        integrity = rctx.attr.integrity,
    )
    if not result.success:
        fail(result)

    whl_path = rctx.path(filename)

    if rctx.attr.patches:
        whl_path = patch_whl(
            rctx,
            python_interpreter = _resolve_python_interpreter(rctx),
            whl_path = whl_path,
            patches = rctx.attr.patches,
            quiet = rctx.attr.quiet,
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

_pypi_file_attrs = {
    "auth_patterns": attr.string_dict(doc = _HTTP_FILE_DOC),
    "canonical_id": attr.string(doc = _HTTP_FILE_DOC),
    "integrity": attr.string(doc = _HTTP_FILE_DOC),
    "netrc": attr.string(doc = _HTTP_FILE_DOC),
    "patches": attr.label_keyed_string_dict(
        doc = """\
A label-keyed-string dict that has patch_strip as the value and the patch to be applied as
a label. The patches are applied in the same order as they are listed in the dictionary.
""",
    ),
    "python_interpreter": attr.string(doc = "The python interpreter to use when patching"),
    "python_interpreter_target": attr.label(doc = "The python interpreter target to use when patching"),
    "quiet": attr.bool(doc = "Silence the stdout/stdeer during patching", default = True),
    "sha256": attr.string(doc = _HTTP_FILE_DOC),
    "urls": attr.string_list(doc = _HTTP_FILE_DOC),
}

pypi_file = repository_rule(
    attrs = _pypi_file_attrs,
    doc = """A rule for downloading a single file from a PyPI like index.""",
    implementation = _impl,
)

# TODO @aignas 2023-12-16: expose getting interpreter
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
